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
from time import sleep
from typing import Dict, List, Optional
from unittest.mock import patch
from urllib.request import urlopen

WINDOWS = sys.platform.startswith(("win", "cygwin")) or (
    sys.platform == "cli" and os.name == "nt"
)
UNIX = sys.platform.startswith(("linux", "freebsd", "openbsd"))
MACOS = sys.platform.startswith("darwin")


if WINDOWS:
    import winreg


class Installer:
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

    def get_user_env(self, name: str) -> Optional[str]:
        if not WINDOWS:
            raise NotImplementedError(
                "can only update environment variables on Windows for now"
            )

        with winreg.ConnectRegistry(None, winreg.HKEY_CURRENT_USER) as root:
            with winreg.OpenKey(root, "Environment", 0, winreg.KEY_ALL_ACCESS) as key:
                value, _ = winreg.QueryValueEx(key, name)

                return value

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

        print(f"{result.stdout or ''}\n{result.stderr or ''}")
        return result

    def scoop(args: str) -> CompletedProcess:
        if not (WINDOWS and self._SCOOP_INSTALLED):
            raise Exception(
                "not running scoop when not on Windows or scoop not installed"
            )

        result = self.shell(f"scoop {args}")
        result.check_returncode()
        return result

    def bootstrap_async(self) -> None:
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
        import trio  # isort:skip

        self.main()

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
        self.UPDATED_ENVIRONMENT["PYTHONPATH"] = str(self.PIP_DIR)
        self._PIP_INSTALLED = True

    def pip(self, args: List[str]) -> None:
        if not self._PIP_INSTALLED:
            self.bootstrap_pip()

        # NOTE: pip forces the --user flag on Microsoft Store Pythons:
        # https://stackoverflow.com/q/63783587
        self.cmd([self.PYTHON_EXECUTABLE, "-m", "pip", *args, "--no-user"])

    def install_scoop(self) -> None:
        if not WINDOWS:
            raise Exception("not installing scoop when not on Windows")

        # Check if scoop is already installed
        self.UPDATED_ENVIRONMENT["PATH"] = self.get_user_env("PATH")

        result = self.shell("scoop which scoop")
        print(f"returncode -> {result.returncode}")
        error_msg = "is not recognized as the name of"
        if (
            error_msg in result.stdout
            or error_msg in result.stderr
            or result.returncode != 0
        ):
            # Set PowerShell's Execution Policy
            args = [
                str(SHELL),
                "-c",
                "& {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser}",
            ]
            print(f"running -> {args!r}")

            set_executionpolicy = Popen(args, text=True)
            print("waiting...")
            sleep(2)
            try:
                stdout, stderr = set_executionpolicy.communicate("A", timeout=2)
            except TimeoutExpired:
                set_executionpolicy.kill()
                stdout, stderr = set_executionpolicy.communicate()

            print(f"{stdout or ''}\n{stderr or ''}")

            print("waiting again...")
            sleep(2)

            result = cmd([str(SHELL), "-c", "& {Get-ExecutionPolicy}"])
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

            self.UPDATED_ENVIRONMENT["PATH"] = self.get_user_env("PATH")
            self._SCOOP_INSTALLED = True

        installed_apps = self.scoop("list").stdout
        for requirement in ["git", "aria2"]:
            if requirement in installed_apps:
                continue

            self.scoop(f"install {requirement}")

        wanted_buckets = ["extras"]
        added_buckets = self.scoop("bucket list").stdout
        for bucket in wanted_buckets:
            if bucket in added_buckets:
                continue

            self.scoop(f"bucket add {bucket}")

    def main(self) -> None:
        import trio

        sys.exit("Not implemented yet")

        # Install dulwich
        self.pip(["install", "dulwich"])
        import dulwich  # isort:skip

        # Install rest of dependencies
        if MACOS or UNIX:
            raise NotImplementedError("only Windows support")

        if WINDOWS:
            # implicitly installs git as well
            self.install_scoop()
            self.scoop("install python")

        for dependency_check in (["git", "--version"], ["python", "--version"]):
            try:
                cmd(dependency_check).check_returncode()
            except CalledProcessError as err:
                raise Exception(
                    f"dependency '{dependency_check!r}' was not found"
                ) from err

        # Clone repository
        self.REPOSITORY_DIR.mkdir(parents=True, exist_ok=True)

        git_status = cmd(["git", "-C", str(self.REPOSITORY_DIR), "status"])
        if git_status.returncode != 0:
            result = cmd(
                [
                    "git",
                    "clone",
                    "https://github.com/mawillcockson/dotfiles.git",
                    str(self.REPOSITORY_DIR),
                ]
            )
            result.check_returncode()

        # Check if repository is clean
        # NOTE: dulwich helpful here
        # raise Exception("dotfiles installed but perhaps there are uncommitted changes")

        # Setup dotfiles
        raise NotImplementedError("setup dotfiles")


if __name__ == "__main__":
    with TemporaryDirectory() as temp_dir:
        Installer(Path(temp_dir).resolve(strict=True)).bootstrap_async()
