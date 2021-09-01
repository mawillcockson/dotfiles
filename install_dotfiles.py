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
from contextlib import asynccontextmanager
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
    from io import BufferedWriter
    from typing import AsyncIterator, List, Tuple, Union

    import trio
    from trio import MemoryReceiveChannel, MemorySendChannel, Process

WINDOWS = sys.platform.startswith(("win", "cygwin")) or (
    sys.platform == "cli" and os.name == "nt"
)
UNIX = sys.platform.startswith(("linux", "freebsd", "openbsd"))
MACOS = sys.platform.startswith("darwin")


if WINDOWS:
    import winreg


def win_get_user_env(name: str) -> Optional[str]:
    if not WINDOWS:
        raise NotImplementedError(
            "can only update environment variables on Windows for now"
        )

    with winreg.ConnectRegistry(None, winreg.HKEY_CURRENT_USER) as root:
        with winreg.OpenKey(root, "Environment", 0, winreg.KEY_ALL_ACCESS) as key:
            value, _ = winreg.QueryValueEx(key, name)

            return value


# pylint: disable=too-many-instance-attributes,too-many-arguments
class Expect:
    """
    Manages running a process as a subprocess, and communicating with it, while
    echoing its output
    """

    # From:
    # https://github.com/mawillcockson/dotfiles/blob/08e973f122b66ceadb009379dfed018a4b9e4eea/trio_watch_and_copy_demo.py
    # Which is inspired by:
    # https://github.com/python-trio/trio/blob/v0.19.0/trio/_subprocess.py#L587-L643

    def __init__(
        self,
        process: "Process",
        printer_send_channel: "MemorySendChannel[bytes]",
        printer_receive_channel: "MemoryReceiveChannel[bytes]",
        notifier_send_channel: "MemorySendChannel[bytes]",
        opened_notifier_receive_channel: "MemoryReceiveChannel[bytes]",
        print_buffer: "BufferedWriter" = sys.stdout.buffer,  # type: ignore
    ):
        self.process = process
        self.printer_send_channel = printer_send_channel
        self.printer_receive_channel = printer_receive_channel
        self.notifier_send_channel = notifier_send_channel
        self.opened_notifier_receive_channel = opened_notifier_receive_channel
        self.print_buffer = print_buffer
        self.stdout: bytes = b""
        self.response_sent = False

    # NOTE: may be able to be combined with copier_recorder()
    async def printer(
        self,
    ) -> None:
        "echoes the process' output, dropping data if necessary"
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        async with self.printer_receive_channel:
            async for chunk in self.printer_receive_channel:
                try:
                    self.print_buffer.write(chunk)
                except BlockingIOError:
                    pass
                self.print_buffer.flush()

    async def copier_recorder(
        self,
    ) -> None:
        """
        records the process' stdout, and mirrors it to printer()

        also sends notifications to expect() every time the process prints
        something
        """
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        assert (
            self.process.stdout is not None
        ), "process must be opened with stdout=PIPE and stderr=STDOUT"

        async with self.process.stdout, self.printer_send_channel, self.notifier_send_channel:
            async for chunk in self.process.stdout:
                # print(f"seen chunk: '{chunk!r}'", flush=True) # debug
                self.stdout += chunk
                await self.printer_send_channel.send(chunk)

                # send notification
                # if it's full, that's fine: if expect() is run, it'll see
                # there's a "pending" notification and check stdout, then wait
                # for another notification
                try:
                    self.notifier_send_channel.send_nowait(b"")
                except trio.WouldBlock:
                    pass
                except trio.BrokenResourceError as err:
                    print(f"cause '{err.__cause__}'")
                    raise err

    async def expect(
        self,
        watch_for: bytes,
        respond_with: bytes,
    ) -> None:
        """
        called inside Expect.open_process()'s with block to watch for, and
        respond to, the process' output
        """
        if not self.process:
            raise Exception("missing process; was this called inside a with statement?")

        assert self.process.stdin is not None, "process must be opened with stdin=PIPE"

        # NOTE: This could be improved to show which responses were sent, and which
        # weren't
        self.response_sent = False
        async with self.opened_notifier_receive_channel.clone() as notifier_receive_channel:
            # print("expect --> opened notifier channel", flush=True) # debug
            async for _ in notifier_receive_channel:
                # print("expect --> received chunk notification", flush=True) # debug
                if not self.response_sent and watch_for in self.stdout:
                    # print("expect --> sending response...", flush=True) # debug
                    await self.process.stdin.send_all(respond_with)
                    self.response_sent = True
                    # print("expect --> response sent", flush=True) # debug

    @classmethod
    @asynccontextmanager
    async def open_process(
        cls, args: "Union[str, List[str]]", env_additions: Dict[str, str] = {}
    ) -> "AsyncIterator[Expect]":
        """
        entry point for using Expect()

        opens the process, opens a nursery, and starts the copier and printer

        this waits until the process is finished, so wrapping in a
        trio.move_on_after() is good to use as a timeout
        """
        printer_channels: (
            "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]"
        ) = trio.open_memory_channel(1)
        printer_send_channel, printer_receive_channel = printer_channels
        notifier_channels: (
            "Tuple[MemorySendChannel[bytes], MemoryReceiveChannel[bytes]]"
        ) = trio.open_memory_channel(0)
        notifier_send_channel, notifier_receive_channel = notifier_channels

        async with notifier_receive_channel:

            with patch.dict("os.environ", values=env_additions) as patched_env:
                async with await trio.open_process(
                    args, stdin=PIPE, stdout=PIPE, stderr=STDOUT, env=patched_env
                ) as process:
                    async with trio.open_nursery() as nursery:
                        expect = cls(
                            process=process,
                            printer_send_channel=printer_send_channel,
                            printer_receive_channel=printer_receive_channel,
                            notifier_send_channel=notifier_send_channel,
                            opened_notifier_receive_channel=notifier_receive_channel,
                        )
                        nursery.start_soon(expect.copier_recorder)
                        nursery.start_soon(expect.printer)

                        yield expect

                        # print("waiting for process") # debug
                        await expect.process.wait()


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
        with patch.dict("os.environ", values=self.UPDATED_ENVIRONMENT) as patched_env:
            result = run(
                args,
                stdin=(stdin or PIPE),
                stderr=STDOUT,
                stdout=PIPE,
                check=False,
                env=patched_env,
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
    REPO_URL = "https://github.com/mawillcockson/dotfiles.git"

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

    async def cmd(
        self,
        args: List[str],
        check: bool = True,
        process_type: str = "cmd",
    ) -> "Expect":

        args_str = self.PROCESS_TYPES.get(
            process_type, self.PROCESS_TYPES["cmd"]
        ).format(args)

        cmd_str = f"{process_type} -> {args_str}"
        print(cmd_str)

        async with Expect.open_process(
            args,
            env_additions=self.UPDATED_ENVIRONMENT,
        ) as expect:
            pass

        if check and expect.process.returncode != 0:
            raise CalledProcessError("returncode is not 0")

        return expect

    async def pip(self, args: List[str]) -> "Expect":
        return await self.cmd(
            [self.PYTHON_EXECUTABLE, "-m", "pip", *args, "--no-user"],
            process_type="pip",
        )

    async def shell(
        self, code: str, check: bool = True, process_type: str = "shell"
    ) -> "Expect":
        # NOTE: "{shell} -c {script}" works with powershell, sh (bash, dash, etc), not sure about other platforms
        return await self.cmd(
            [str(self.SHELL), "-c", code], check=check, process_type=process_type
        )

    async def scoop(self, args: str) -> "Expect":
        if not (WINDOWS and self._SCOOP_INSTALLED):
            raise Exception(
                "not running scoop when not on Windows or scoop not installed"
            )

        return await self.shell(f"scoop {args}", check=True, process_type="scoop")

    async def install_scoop(self) -> None:
        if not WINDOWS:
            raise Exception("not installing scoop when not on Windows")

        # Check if scoop is already installed
        self.UPDATED_ENVIRONMENT["PATH"] = win_get_user_env("PATH")

        expect = await self.shell("scoop which scoop", check=False)
        self._SCOOP_INSTALLED = (
            "is not recognized as the name of" not in expect.stdout.decode()
            and expect.process.returncode == 0
        )

        if not self._SCOOP_INSTALLED:
            # Set PowerShell's Execution Policy
            args = [
                str(self.SHELL),
                "-c",
                "& {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser}",
            ]
            print(f"running -> {args!r}")

            with trio.move_on_after(7):
                async with Expect.open_process(
                    args, env_additions=self.UPDATED_ENVIRONMENT
                ) as expect:

                    with trio.move_on_after(2):
                        await expect.expect(
                            watch_for=b'(default is "N"):',
                            respond_with=b"A",
                        )

            # NOTE: don't have to check if the response was sent, because
            # sometimes the execution policy is set without ever sending a
            # response (i.e. if the execution policy was already set).
            # Instead, just check if the policy is set correctly.

            result = await self.cmd(
                [str(self.SHELL), "-c", "& {Get-ExecutionPolicy}"], check=False
            )
            if not "RemoteSigned" in result.stdout.decode():
                raise Exception("could not set PowerShell Execution Policy")

            # Install Scoop
            result = await self.cmd(
                [str(self.SHELL), "-c", "& {iwr -useb https://get.scoop.sh | iex}"]
            )
            stdout = result.stdout.decode().lower()
            if not (
                "scoop was installed successfully!" in stdout
                or "scoop is already installed" in stdout
            ):
                raise Exception("scoop was not installed")

            self.UPDATED_ENVIRONMENT["PATH"] = win_get_user_env("PATH")
            self._SCOOP_INSTALLED = True

        installed_apps = (await self.scoop("list")).stdout.decode()
        for requirement in ["aria2", "git", "python"]:
            if requirement in installed_apps:
                continue

            await self.scoop(f"install {requirement}")

        wanted_buckets = ["extras"]
        added_buckets = (await self.scoop("bucket list")).stdout.decode()
        for bucket in wanted_buckets:
            if bucket in added_buckets:
                continue

            await self.scoop(f"bucket add {bucket}")

    async def main(self) -> None:
        # Install rest of dependencies
        if MACOS or UNIX:
            raise NotImplementedError("only Windows supported currently")

        if WINDOWS:
            # implicitly installs git as well
            await self.install_scoop()

        for dependency_check in (["git", "--version"], ["python", "--version"]):
            try:
                await self.cmd(dependency_check, check=True)
            except CalledProcessError as err:
                raise Exception(
                    f"dependency '{dependency_check!r}' was not found"
                ) from err

        ## Clone dotfiles repository
        self.REPOSITORY_DIR.mkdir(parents=True, exist_ok=True)

        # Check if there's an existing repository, and if that repository is clean
        # NOTE::FUTURE dulwich does not support submodules
        # https://github.com/dulwich/dulwich/issues/506
        repo_status = await self.cmd(["git", "-C", str(self.REPOSITORY_DIR), "status", "--porcelain"], check=False)
        if "not a git repository" in repo_status.stdout.decode().lower():
            await self.cmd(
                [
                    "git",
                    "clone",
                    "--recurse-submodules",
                    self.REPO_URL,
                    str(self.REPOSITORY_DIR),
                ]
            )

        # Three scenarios:
        # - Repo exists and is completely clean and up to date
        # - Repo exists and there are uncommitted changes
        # - Repo exists and there are un-pushed changes
        #
        # The last one can be helped with dulwich if issue 506 is resolved, or
        # complex git commands, like:
        # https://stackoverflow.com/a/6133968
        #
        # For now I'm saying "deal with it manually"

        # - Repo exists and there are changes

        # NOTE: optimistically try to pull in new upstream changes; could fail in numerous ways
        await self.cmd(["git", "-C", str(self.REPOSITORY_DIR), "pull", "--ff-only"])

        # Run dotdrop
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
