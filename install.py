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
        "If on Debian, please install it with either of\n"
        "sudo apt-get install python3-venv\n"
        "su -c 'apt-get install python3-venv'",
        file=sys.stderr,
    )
    sys.exit(1)

### Program defaults
# NOTE: Make configurable through arguments/flags/environment variables
default_install_dir: str = "~/projects/dotfiles"
PROG_NAME: str = "install"
TASK_FUNC_PREFIX: str = "atask"
#DEFAULT_INSTALL_CLI: list = "--install=all --profile=".split()

### Tasks to execute with invoke ###


def atask_install_git_windows(ctx):
    print("installing git")
    import time
    time.sleep(5)
    print("Installed git")


### Setup and argument parsing ###


def ensure_invoke() -> None:
    ### Realized we don't need this: we're loading invoke, invoke will handle all the sys.argv
    ## Parse arguments with argparse since invoke hasn't been found
    #parser = argparse.ArgumentParser(
    #    prog=PROG_NAME,
    #    description="Installs tools needed to use github.com/mawillcockson/dotfiles",
    #)
    #parser.add_argument(
    #    "directory",
    #    default="~/projects/dotfiles",
    #    help="Directory that will contain the .venv directory for this environment",
    #)
    #directory = parser.parse_args().directory

    #project_dir = Path()
    #if not directory:
    #    project_dir = Path(default_install_dir).expanduser()
    #elif not Path(directory).is_dir():
    #    try:
    #        project_dir = Path(directory)
    #        project_dir.mkdir(parents=True, exist_ok=True)
    #    except FileExistsError as err:
    #        print(
    #            f"{directory} appears to already exist, and is not a directory",
    #            file=sys.stderr,
    #        )
    #        sys.exit(1)

    ## Make a venv
    # Must make a variable to hold the TemopraryDirectory; wrapping it in Path() effectively deletes it,
    # as Path() discards it, and the dir is removed upon deletion of the object
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
        print(f"Could not find an lib folders in {venv_dir}", file=sys.stderr)
        sys.exit(1)
    site_folders = [
        (p / "site-packages") for p in lib_dirs if (p / "site-packages").is_dir()
    ]
    python_ver = f"python{sys.version_info.major}{sys.version_info.minor}"
    site_folders.extend(
        (p / python_ver / "site-packages")
        for p in lib_dirs
        if (p / python_ver / "site-packages").is_dir()
    )
    sys.path.extend(map(str, site_folders))

    ## I wish this worked, but it doesn't easily work for folders
    # invoke_dirs = list( filter(lambda p: "invoke" in map(lambda p: str(p.name), p.iterdir()), site_folders) )
    # if len(invoke_dirs) < 1:
    #    print("Can' find the invoke directory", file=sys.stderr)
    #    sys.exit(1)

    ## Import module manually
    # spec = importlib.util.spec_from_file_location("invoke", invoke_dirs[0]/"invoke")
    # if not spec:
    #    print("Python failed to import invoke", file=sys.stderr)
    #    sys.exit(1)
    # module = importlib.util.module_from_spec(spec)
    # if not spec:
    #    print("Python failed to import invoke", file=sys.stderr)
    #    sys.exit(1)
    # sys.modules["invoke"] = module

    try:
        import invoke
    except ImportError as err:
        print(f"Can't import invoke package:\n{err}", file=sys.stderr)
        print(sys.path)
        sys.exit(1)


def main() -> None:
    # This says importlib.util.find_spec() can test if a movule is importable:
    # https://docs.python.org/3/library/importlib.html#importlib.util.find_spec
    if not importlib.util.find_spec("invoke"):
        ensure_invoke()

    from invoke import task, Program, Config, Collection
    from invoke.config import merge_dicts

    namespace = Collection()
    globs = dict(globals())
    for name in globs:
        if re.match(f"^{TASK_FUNC_PREFIX}.*", name) and callable(globs[name]):
            namespace.add_task(task(globs[name]))

    class SetupConfig(Config):
        prefix = PROG_NAME

        @staticmethod
        def global_defaults():
            base_defaults = Config.global_defaults()
            overrides = {"tasks": {"collection_name": PROG_NAME}}
            return merge_dicts(base=base_defaults, updates=overrides)

    program = Program(
        name=PROG_NAME, namespace=namespace, config_class=SetupConfig, version="0.0.1"
    )
    #program.run(argv=[PROG_NAME, *DEFAULT_INSTALL_CLI])
    program.run()

if __name__ == "__main__":
    main()
