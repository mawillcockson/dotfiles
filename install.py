#!/usr/bin/env python

import argparse
import importlib.util
import re
import sys
import tempfile
from pathlib import Path
from subprocess import run

try:
    import venv
except ImportError as err:
    print(
        "Cannot find Python venv module\n"
        "If on Debian, please install it with either of:\n"
        "su -c 'apt-get install python3-venv'\n",
        "sudo apt-get install python3-venv",
        file=sys.stderr,
    )
    sys.exit(1)

### Program defaults
# NOTE: Make configurable through arguments/flags/environment variables
default_install_dir: str = "~/projects/dotfiles"
PROG_NAME: str = "install"
TASK_FUNC_PREFIX: str = "atask"

### Tasks to execute with invoke ###


def atask_main(ctx):
    print("Running tasks...")

def atask_install_git_windows(ctx):
    print("installing git")
    import time

    time.sleep(5)
    print("Installed git")


### Setup and argument parsing ###


def ensure_invoke() -> tempfile.TemporaryDirectory:
    ## Make a venv
    # Must make a variable to hold the TemopraryDirectory; wrapping it in Path() effectively deletes it,
    # as passing the call to TemporaryDirectory directly to Path() discards it once Path drops a reference to it,
    # and the dir is removed upon deletion of the object
    temp_dir = tempfile.TemporaryDirectory()
    venv_dir = Path(temp_dir.name)
    print(f"Installing virtual environment for Python into '{venv_dir}'")

    venv.create(
        env_dir=venv_dir,
        clear=False,  # We explicitly want to fail if the dir isn't empty
        with_pip=True,
    )

    # Install invoke
    print(f"Installing invoke module into {venv_dir}")

    # The venv module uses this same platform detection test to decide whether to use /Scripts or /bin
    # https://github.com/python/cpython/blob/1df65f7c6c00dfae9286c7a58e1b3803e3af33e5/Lib/venv/__init__.py#L120
    if sys.platform == "win32":
        venv_python = (venv_dir / "Scripts" / "python.exe").absolute()
    else:
        venv_python = (venv_dir / "bin" / "python").absolute()

    if not venv_python.is_file():  # Also tests for existence
        print(
            f"{venv_dir} exists but cannot find python{'.exe' if sys.platform == 'win32' else ''}",
            file=sys.stderr,
        )
        sys.exit(1)

    ret = run(
        [str(venv_python), "-m", "pip", "install", "invoke"],
        capture_output=True,
        text=True,
    )

    if not ret.returncode == 0:
        print(f"Error installing invoke:\n{ret.stderr}", file=sys.stderr)
        sys.exit(1)

    print(ret.stdout)

    # Find the site-packages folders
    lib_dirs = [
        x
        for x in venv_dir.iterdir()
        if x.is_dir() and x.name in ["Lib", "lib", "lib64"]
    ]
    if len(lib_dirs) < 1:
        print(f"Could not find any lib folders in {venv_dir}", file=sys.stderr)
        sys.exit(1)
    site_folders = [
        (p / "site-packages") for p in lib_dirs if (p / "site-packages").is_dir()
    ]
    # On some platforms, and intermediate "python3.7" folder is used: /tmp/tmp2tcvye33/lib/python3.7/site-packages
    python_ver = f"python{sys.version_info.major}.{sys.version_info.minor}"
    site_folders.extend(
        (p / python_ver / "site-packages")
        for p in lib_dirs
        if (p / python_ver / "site-packages").is_dir()
    )
    sys.path.extend(map(str, site_folders))

    # importlib.util.spec_from_file_location() supposedly can confirm if a module exists at a location,
    # but importlib.util.module_from_spec() loads only a single file, whereas the import statement does more?
    # Anyways, we're going to be import invoke anyways, so doing the real thing is the best way to test.
    try:
        import invoke
    except ImportError as err:
        print(f"Can't import invoke package:\n{err}", file=sys.stderr)
        print(sys.path)
        sys.exit(1)

    return temp_dir


def main() -> None:
    # This says importlib.util.find_spec() can test if a module is currently importable:
    # https://docs.python.org/3/library/importlib.html#importlib.util.find_spec
    if not importlib.util.find_spec("invoke"):
        temp_dir = ensure_invoke()

    from invoke import task, Program, Config, Collection
    from invoke.config import merge_dicts

    namespace = Collection()
    globs = dict(globals())
    for name in globs:
        # If there's a function named TASK_FUNC_PREFIX_main, mark it as the default, unless one has already
        # been marked as such
        if re.match(f"^{TASK_FUNC_PREFIX}_main$", name) and callable(globs[name]) and not namespace.default:
            namespace.add_task(task(globs[name]), default=True)
        if re.match(f"^{TASK_FUNC_PREFIX}.*", name) and callable(globs[name]):
            namespace.add_task(task(globs[name]))

    class SetupConfig(Config):
        prefix: str = PROG_NAME

        @staticmethod
        def global_defaults():
            base_defaults = Config.global_defaults()
            overrides = {"tasks": {"collection_name": PROG_NAME}}
            return merge_dicts(base=base_defaults, updates=overrides)

    program = Program(
        name=PROG_NAME, namespace=namespace, config_class=SetupConfig, version="0.0.1"
    )
    program.run()


if __name__ == "__main__":
    main()
