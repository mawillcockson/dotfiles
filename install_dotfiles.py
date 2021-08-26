#!/usr/bin/env python
"""
hopefully doesn't mess anything up too badly


Significant inspiration was taken from:

https://github.com/python-poetry/poetry/blob/c967a4a5abc6a0edd29c57eca307894f6e1c4f16/install-poetry.py

Steps:

 - Ensure dependencies (git)
 - Download repository
 - Run dotdrop from the repo
"""
import os
import sys
import time
from pathlib import Path
from shutil import which
from subprocess import (
    PIPE,
    STDOUT,
    CalledProcessError,
    CompletedProcess,
    Popen,
    TimeoutExpired,
    run,
)
from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Dict, List, Optional, Union
from unittest.mock import patch
from urllib.request import urlopen

trio = None

if TYPE_CHECKING:
    import trio
    from trio import Process

WINDOWS = sys.platform.startswith(("win", "cygwin")) or (
    sys.platform == "cli" and os.name == "nt"
)
UNIX = sys.platform.startswith(("linux", "freebsd", "openbsd"))
MACOS = sys.platform.startswith("darwin")


if WINDOWS:
    import winreg


def get_user_env(name: str) -> Optional[str]:
    if not WINDOWS:
        raise NotImplementedError(
            "can only update environment variables on Windows for now"
        )

    with winreg.ConnectRegistry(None, winreg.HKEY_CURRENT_USER) as root:
        with winreg.OpenKey(root, "Environment", 0, winreg.KEY_ALL_ACCESS) as key:
            value, _ = winreg.QueryValueEx(key, name)

            return value


class Bootstrapper:
    UPDATED_ENVIRONMENT: Dict[str, str] = {}
    SHELL: Optional[Path] = None
    _SCOOP_INSTALLED = False
    _PIP_INSTALLED = False
    TEMP_DIR: Optional[Path] = None
    PIP_DIR: Optional[Path] = None
    VIRTUALENV_INSTALL_DIR: Optional[Path] = None
    VENV_DIR: Optional[Path] = None
    CACHE_DIR: Optional[Path] = None
    PYTHON_EXECUTABLE: str = sys.executable

    def __init__(self, temp_dir: Path) -> None:
        if WINDOWS:
            import winreg

            powershell_str = which("powershell")
            powershell_path = Path(powershell_str).resolve()
            if not (powershell_str and powershell_path.is_file()):
                raise FileNotFoundError(
                    f"powershell not found at '{powershell_str}' or '{powershell_path}'"
                )
            self.SHELL = powershell_path

        self.REPOSITORY_DIR = Path("~/projects/dotfiles/").expanduser().resolve()
        self.TEMP_DIR = temp_dir
        assert self.TEMP_DIR.is_dir()
        self.PIP_DIR = self.TEMP_DIR / "pip"
        self.PIP_DIR.mkdir(exist_ok=True)
        self.VIRTUALENV_INSTALL_DIR = self.TEMP_DIR / "virtualenv"
        self.VIRTUALENV_INSTALL_DIR.mkdir(exist_ok=True)
        self.VENV_DIR = self.TEMP_DIR / "venv"
        self.VENV_DIR.mkdir(exist_ok=True)
        self.CACHE_DIR = self.TEMP_DIR / "cache"
        self.CACHE_DIR.mkdir(exist_ok=True)
        self._PIP_INSTALLED = (
            self.cmd([self.PYTHON_EXECUTABLE, "-m", "pip", "--version"]).returncode == 0
        )
        self._PIP_INSTALLED = False

    def cmd(self, args: List[str], stdin: str = "") -> CompletedProcess:
        print(f"running -> {args!r}")
        if self.UPDATED_ENVIRONMENT:
            with patch.dict(
                "os.environ", values=self.UPDATED_ENVIRONMENT
            ) as patched_env:
                result = run(
                    args,
                    stdin=(stdin or PIPE),
                    stderr=STDOUT,
                    stdout=PIPE,
                    check=False,
                    env=patched_env,
                )
        else:
            result = run(
                args, stdin=(stdin or PIPE), stderr=STDOUT, stdout=PIPE, check=False
            )

        print(result.stdout.decode() or "")
        return result

    def shell(self, code: str) -> CompletedProcess:
        print(f'shell -> "{code}"')
        if self.UPDATED_ENVIRONMENT:
            with patch.dict(
                "os.environ", values=self.UPDATED_ENVIRONMENT
            ) as patched_env:
                result = run(
                    code,
                    text=True,
                    capture_output=True,
                    check=False,
                    shell=True,
                    executable=str(self.SHELL) or None,
                    env=patched_env,
                )
        else:
            result = run(
                code,
                text=True,
                capture_output=True,
                check=False,
                shell=True,
                executable=str(self.SHELL) or None,
            )

        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr)
        return result

    def main(self) -> None:
        try:
            import virtualenv
        except ImportError:
            self.bootstrap_virtualenv()

        import virtualenv  # isort:skip

        session = virtualenv.cli_run([str(self.VENV_DIR), "--clear", "--download"])
        if WINDOWS:
            venv_python = self.VENV_DIR / "Scripts" / "python.exe"
            venv_modules = self.VENV_DIR / "Lib" / "site-packages"
        else:
            raise NotImplementedError("only Windows supported right now")

        if not (venv_python and venv_python.is_file()):
            raise Exception(
                f"could not find a virtual environment python at '{venv_python}'"
            )

        assert venv_modules.is_dir(), f"missing directory '{venv_modules}'"

        self.PYTHON_EXECUTABLE = str(venv_python)
        sys.path.insert(0, str(venv_modules))

        # Install trio
        self.pip(["install", "trio"])
        import trio as trio_module  # isort:skip

        global trio
        trio = trio_module

        installer = Installer(
            temp_dir=self.TEMP_DIR,
            repository_dir=self.REPOSITORY_DIR,
            shell=self.SHELL,
            venv_dir=self.VENV_DIR,
            cache_dir=self.CACHE_DIR,
            python_executable=self.PYTHON_EXECUTABLE,
            updated_environment=self.UPDATED_ENVIRONMENT,
        )
        trio.run(installer.main)

    def bootstrap_virtualenv(self) -> None:
        if not self._PIP_INSTALLED:
            self.bootstrap_pip()

        self.VIRTUALENV_INSTALL_DIR.mkdir(exist_ok=True)
        self.pip(
            ["install", "virtualenv", "--target", str(self.VIRTUALENV_INSTALL_DIR)]
        )
        sys.path.insert(0, str(self.VIRTUALENV_INSTALL_DIR))
        import virtualenv  # isort:skip

    def bootstrap_pip(self) -> None:
        if self._PIP_INSTALLED:
            return

        # NOTE: On Windows, the SSL certificates for some reason aren't
        # available until a web request is made that absolutely requires
        # them
        # If it's a truly fresh install, then any urlopen() call to an
        # https:// url will fail with an SSL context error:
        # >> ssl.SSLCertVerificationError: [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate
        self.shell("iwr -useb https://bootstrap.pypa.io")

        # https://pip.pypa.io/en/stable/installation/#get-pip-py
        get_pip_file = self.CACHE_DIR / "get_pip.py"
        get_pip_file.touch()
        with get_pip_file.open(mode="wb") as file:
            with urlopen("https://bootstrap.pypa.io/get-pip.py") as request:
                while request.peek(1):
                    file.write(request.read(8192))

        # NOTE: pip forces the --user flag on Microsoft Store Pythons:
        # https://stackoverflow.com/q/63783587
        self.cmd(
            [
                self.PYTHON_EXECUTABLE,
                str(get_pip_file),
                "--target",
                str(self.PIP_DIR),
                "--no-user",
            ]
        )
        sys.path.insert(0, str(self.PIP_DIR))
        # Causes Python to find the downloaded pip module
        self.UPDATED_ENVIRONMENT["PYTHONPATH"] = str(self.PIP_DIR)
        self._PIP_INSTALLED = True

    def pip(self, args: List[str]) -> None:
        if not self._PIP_INSTALLED:
            self.bootstrap_pip()

        # NOTE: pip forces the --user flag on Microsoft Store Pythons:
        # https://stackoverflow.com/q/63783587
        self.cmd([self.PYTHON_EXECUTABLE, "-m", "pip", *args, "--no-user"])


class Installer:
    SHELL: Optional[Path] = None
    PYTHON_EXECUTABLE: str = sys.executable
    UPDATED_ENVIRONMENT: Dict[str, str] = {}
    _SCOOP_INSTALLED: bool = False
    PROCESS_TYPES: Dict[str, str] = {
        "cmd": "{0!r}",
        "shell": '"{0}"',
        "pip": "{0}",
        "scoop": "{0}",
    }

    def __init__(
        self,
        temp_dir: Path,
        repository_dir: Path,
        shell: Optional[Path] = None,
        venv_dir: Optional[Path] = None,
        cache_dir: Optional[Path] = None,
        python_executable: str = sys.executable,
        updated_environment: Dict[str, str] = {},
    ) -> None:
        if WINDOWS:
            if not shell:
                powershell_str = which("powershell")
                powershell_path = Path(powershell_str).resolve()
                if not (powershell_str and powershell_path.is_file()):
                    raise FileNotFoundError(
                        f"powershell not found at '{powershell_str}' or '{powershell_path}'"
                    )
                self.SHELL = powershell_path

            else:
                self.SHELL = shell

        self.REPOSITORY_DIR = repository_dir
        self.TEMP_DIR = temp_dir
        assert self.TEMP_DIR.is_dir()
        self.VENV_DIR = venv_dir or (self.TEMP_DIR / "venv")
        self.VENV_DIR.mkdir(exist_ok=True)
        self.CACHE_DIR = cache_dir or (self.TEMP_DIR / "cache")
        self.CACHE_DIR.mkdir(exist_ok=True)
        self.PYTHON_EXECUTABLE = python_executable
        self.UPDATED_ENVIRONMENT.update(updated_environment)

    async def scoop(args: str) -> CompletedProcess:
        if not (WINDOWS and self._SCOOP_INSTALLED):
            raise Exception(
                "not running scoop when not on Windows or scoop not installed"
            )

        return await self.shell(f"scoop {args}", check=True, process_type="scoop")

    async def cmd(
        self,
        args: Union[str, List[str]],
        check: bool = True,
        shell: bool = False,
        process_type: str = "cmd",
    ) -> CompletedProcess:
        args_str = self.PROCESS_TYPES.get(
            process_type, self.PROCESS_TYPES["cmd"]
        ).format(args)
        if shell:
            assert isinstance(args, str), "args must be a string of code for the shell"

        cmd_str = f"{process_type} -> {args_str}"
        print(cmd_str)

        # NOTE::FUTURE trio.run_process() cannot both capture stdout/stderr AND mirror it
        # This copies from trio.run_process():
        # https://github.com/python-trio/trio/blob/v0.19.0/trio/_subprocess.py#L587-L643

        with patch.dict(
            "os.environ", values=self.UPDATED_ENVIRONMENT
        ) as patched_env:
            async with await trio.open_process(
                args,
                stdin=None,
                stdout=PIPE,
                stderr=STDOUT,
                shell=shell,
                executable=str(self.SHELL) or None if shell else None,
                check=check,
                env=patched_env,
                ) as process:
                data: bytes = process.stdout.receive_some()
                while process.returncode == None:
                    try:
                        data += process.stdout.receive_some()


    async def shell(self, code: str, check: bool = True) -> CompletedProcess:
        return await self.cmd(code, check=check, shell=True, process_type="shell")

    async def install_scoop(self) -> None:
        if not WINDOWS:
            raise Exception("not installing scoop when not on Windows")

        # Check if scoop is already installed
        self.UPDATED_ENVIRONMENT["PATH"] = get_user_env("PATH")

        process = await self.shell("scoop which scoop", check=False)
        error_msg = "is not recognized as the name of"
        if error_msg in process.stdout.decode() or process.returncode != 0:
            # Set PowerShell's Execution Policy
            args = [
                str(self.SHELL),
                "-c",
                "& {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser}",
            ]
            print(f"running -> {args!r}")

            async with await trio.open_process(
                args, stdin=PIPE, stdout=PIPE, stderr=STDOUT, check=False, timeout=2
            ) as set_executionpolicy:
                # Wait for warning message or process completion or timeout
                data: bytes = await set_executionpolicy.stdio.receive_some()
                expect = '(default is "N"):'.encode()
                while expect not in data or set_executionpolicy.returncode == None:
                    data += await set_executionpolicy.stdio.receive_some()

                if expect not in data and set_executionpolicy.returncode != None:
                    raise Exception("Set-ExecutionPolicy message never received")

                # respond to warning message with encoded "A"
                await set_executionpolicy.stdio.send_all("A".encode())

                # wait for process completion or timeout
                await set_executionpolicy.wait()

            result = await self.cmd(
                [str(self.SHELL), "-c", "& {Get-ExecutionPolicy}"], check=False
            )
            if not "RemoteSigned" in result.stdout.decode():
                raise Exception("could not set PowerShell Execution Policy")

            # Install Scoop
            result = self.cmd(
                [str(self.SHELL), "-c", "iwr -useb https://get.scoop.sh | iex"]
            )
            if (
                not "scoop was installed successfully!"
                in result.stdout.decode().lower()
            ):
                raise Exception("scoop was not installed")

            self.UPDATED_ENVIRONMENT["PATH"] = get_user_env("PATH")
            self._SCOOP_INSTALLED = True

        installed_apps = self.scoop("list").stdout.decode()
        for requirement in ["git", "aria2"]:
            if requirement in installed_apps:
                continue

            self.scoop(f"install {requirement}")

        wanted_buckets = ["extras"]
        added_buckets = self.scoop("bucket list").stdout.decode()
        for bucket in wanted_buckets:
            if bucket in added_buckets:
                continue

            self.scoop(f"bucket add {bucket}")

    async def pip(self, args: List[str]) -> CompletedProcess:
        return await self.cmd(
            [self.PYTHON_EXECUTABLE, "-m", "pip", *args, "--no-user"],
            process_type="pip",
        )

    async def main(self) -> None:
        # Install dulwich
        await self.pip(["install", "dulwich"])
        import dulwich  # isort:skip

        # Install rest of dependencies
        if MACOS or UNIX:
            raise NotImplementedError("only Windows support")

        if WINDOWS:
            # implicitly installs git as well
            await self.install_scoop()
            await self.scoop("install python")

        async for dependency_check in (["git", "--version"], ["python", "--version"]):
            try:
                process = await self.cmd(dependency_check, check=True)
            except CalledProcessError as err:
                raise Exception(
                    f"dependency '{dependency_check!r}' was not found"
                ) from err

        ## Clone dotfiles repository
        self.REPOSITORY_DIR.mkdir(parents=True, exist_ok=True)

        # Check if there's an existing repository, and if that repository is
        # clean
        # NOTE: dulwich helpful here
        # raise Exception("dotfiles installed but perhaps there are uncommitted changes")

        # Clone or pull repo

        # Run dotdrop
        print("done")
        sys.exit(0)
        raise NotImplementedError("setup dotfiles")


if __name__ == "__main__":
    with TemporaryDirectory() as temp_dir:
        temp_dir_path = Path(temp_dir).resolve(strict=True)
        bootstrapper = Bootstrapper(temp_dir_path)
        bootstrapper.main()
        # import trio  # isort:skip

        # installer = Installer(
        #     temp_dir=bootstrapper.TEMP_DIR,
        #     repository_dir=bootstrapper.REPOSITORY_DIR,
        #     shell=bootstrapper.SHELL,
        #     venv_dir=bootstrapper.VENV_DIR,
        #     cache_dir=bootstrapper.CACHE_DIR,
        #     python_executable=bootstrapper.PYTHON_EXECUTABLE,
        #     updated_environment=bootstrapper.UPDATED_ENVIRONMENT,
        # )
        # trio.run(installer.main)
