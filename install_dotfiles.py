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
import sys
import os
from shutil import which
from subprocess import run, PIPE, STDOUT, CompletedProcess, CalledProcessError, Popen, TimeoutExpired
from typing import List, Dict, Optional
from time import sleep
from pathlib import Path
from unittest.mock import patch


WINDOWS = sys.platform.startswith(("win", "cygwin")) or (sys.platform == "cli" and os.name == "nt")
UNIX = sys.platform.startswith(("linux", "freebsd", "openbsd"))
MACOS = sys.platform.startswith("darwin")
UPDATED_ENVIRONMENT = {}


if WINDOWS:
    import winreg

    powershell_str = which("powershell")
    powershell_path = Path(powershell_str).resolve()
    if not (powershell_str and powershell_path.is_file()):
        raise FileNotFoundError(f"powershell not found at '{powershell_str}' or '{powershell_path}'")
    SHELL = powershell_path


def get_sys_env(name):
    # from:
    # https://stackoverflow.com/a/38546615
    key = winreg.CreateKey(winreg.HKEY_LOCAL_MACHINE, r"System\CurrentControlSet\Control\Session Manager\Environment")
    return winreg.QueryValueEx(key, name)[0]

def get_user_env(name):
    # from:
    # https://stackoverflow.com/a/38546615
    key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, r"Environment")
    return winreg.QueryValueEx(key, name)[0]


def cmd(args: List[str], stdin: str = "") -> CompletedProcess:
    print(f"running -> {args!r}")
    if UPDATED_ENVIRONMENT:
        with patch.dict("os.environ", values=UPDATED_ENVIRONMENT) as patched_env:
            result = run(args, stdin=(stdin or PIPE), stderr=STDOUT, stdout=PIPE, check=False, env=patched_env)
    else:
        result = run(args, stdin=(stdin or PIPE), stderr=STDOUT, stdout=PIPE, check=False)
    print(result.stdout.decode() or "")
    return result


def shell(code: str) -> CompletedProcess:
    print(f'shell -> "{code}"')
    if UPDATED_ENVIRONMENT:
        with patch.dict("os.environ", values=UPDATED_ENVIRONMENT) as patched_env:
            result = run(code, text=True, capture_output=True, check=False, shell=True, executable=str(SHELL) or None, env=patched_env)
    else:
        result = run(code, text=True, capture_output=True, check=False, shell=True, executable=str(SHELL) or None)

    print(f"{result.stdout or ''}\n{result.stderr or ''}")
    return result


def scoop(args: str) -> CompletedProcess:
        if not WINDOWS:
            raise Exception("not running scoop when not on Windows")

        result = shell(f"scoop {args}")
        result.check_returncode()
        return result


def install_dependencies() -> None:
    if MACOS or UNIX:
        raise NotImplementedError("only WINDOWS support")

    if WINDOWS:
        # implicitly installs dependencies
        install_scoop()

    for dependency_check in (["git", "--version"], ["python", "--version"], ["python", "-m", "pip", "--version"]):
        try:
            cmd(dependency_check).check_returncode()
        except CalledProcessError as err:
            raise Exception(f"dependency '{dependency_check!r}' was not found") from err


def install_scoop() -> None:
    if not WINDOWS:
        raise Exception("not installing scoop when not on Windows")

    # Check if scoop is already installed
    UPDATED_ENVIRONMENT["PATH"] = get_user_env("PATH")

    result = shell("scoop which scoop")
    print(f"returncode -> {result.returncode}")
    error_msg = "is not recognized as the name of"
    if error_msg in result.stdout or error_msg in result.stderr or result.returncode != 0:
        # Set PowerShell's Execution Policy
        args = [str(SHELL), "-c", "& {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser}"]
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
        result = cmd([str(SHELL), "-c", "iwr -useb https://get.scoop.sh | iex"])
        if not "scoop was installed successfully!" in result.stdout.decode().lower():
            raise Exception("scoop was not installed")

        UPDATED_ENVIRONMENT["PATH"] = get_user_env("PATH")

    
    installed_apps = scoop("list").stdout
    for requirement in ["git", "aria2", "python"]:
        if requirement in installed_apps:
            continue

        scoop(f"install {requirement}")

    wanted_buckets = ["extras"]
    added_buckets = scoop("bucket list").stdout
    for bucket in wanted_buckets:
        if bucket in added_buckets:
            continue

        scoop(f"bucket add {bucket}")


def main() -> None:
    # Install dependencies
    if not which("git") or cmd(["git", "--version"]):
        install_dependencies()

    # Clone repository
    repository_dir = Path("~/projects/dotfiles/").expanduser().resolve()
    repository_dir.mkdir(parents=True, exist_ok=True)

    git_status = cmd(["git", "-C", str(repository_dir), "status"])
    if git_status.returncode != 0:
        result = cmd(["git", "clone", "https://github.com/mawillcockson/dotfiles.git", str(repository_dir)])
        result.check_returncode()

    # Check if repository is clean
        #raise Exception("dotfiles installed but perhaps there are uncommitted changes")

    # Setup dotfiles
    raise NotImplementedError("setup dotfiles")


if __name__ == "__main__":
    main()
