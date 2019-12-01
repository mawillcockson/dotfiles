#!/usr/bin/env python

import sys
from pathlib import Path
default_install_dir = "~/projects/dotfiles"

def install_git_windows():
    print("installing git")
    import time
    time.sleep(5)
    print("Installed git")

def create_venv(directory: Path) -> Path:
    # Make a venv
    venv_dir = (directory / ".venv").absolute()
    print(f"Installing virtual environment for Python into '{venv_dir}'")

    if venv_dir in Path(sys.executable).parents or venv_dir.exists():
        print(f"Using existing .venv in\n{venv_dir}")
    else:
        import venv

        venv.create(
            env_dir=venv_dir,
            clear=False,
            with_pip=True,
        )

    # Install invoke
    print(f"Installing invoke module into {venv_dir}")

    from subprocess import run

    # The venv module uses this same platform detection test to decide whether to use /Scripts or /bin
    # https://github.com/python/cpython/blob/1df65f7c6c00dfae9286c7a58e1b3803e3af33e5/Lib/venv/__init__.py#L120
    if sys.platform == "win32":
        venv_python = (venv_dir / "Scripts" / "python.exe").absolute()
    else:
        venv_python = (venv_dir / "bin" / "python").absolute()
    
    if not venv_python.is_file(): # Also tests for existence
        print(f"{venv_dir} exists but cannot find python{'.exe' if sys.platform == 'win32' else ''}", file=sys.stderr)
        sys.exit(1)

    ret = run(
        [str(venv_python), "-m", "pip", "install", "invoke"], capture_output=True, text=True
    )

    if not ret.returncode == 0:
        print(f"Error installing invoke:\n{ret.stderr}", file=sys.stderr)
        sys.exit(1)

    print(ret.stdout)

    # Find the site-packages
    lib_dirs = [x for x in venv_dir.iterdir() if x.is_dir() and x.name in ["Lib", "lib", "lib64"]]
    if len(lib_dirs) < 1:
        print(f"Could not find an lib folders in {venv_dir}", file=sys.stderr)
        sys.exit(1)
    site_folders = [(p/"site_packages") for p in lib_dirs if (p/"site_packages").is_dir()]
    python_ver = f"python{sys.version_info.major}{sys.version_info.minor}"
    site_folders.extend( (p/python_ver/"site_packages") for p in lib_dirs if (p/python_ver/"site_packages").is_dir() )
    sys.path.extend(map(str, site_folders))

    try:
        import invoke
    except ImportError as err:
        print(f"Can't find installed invoke package:\n{err}", file=sys.stderr)
        sys.exit(1)

    return venv_python

def ensure_venv(directory: str) -> Path:
    if not directory:
        venv_dir = Path(default_install_dir).expanduser()
    elif not Path(directory).is_dir():
        try:
            venv_dir = Path(directory)
            venv_dir.mkdir(parents=True, exist_ok=True)
        except FileExistsError as err:
            print(f"{directory} appears to already exist, and is not a directory", file=sys.stderr)
            sys.exit(1)


    return create_venv(venv_dir)

if __name__ == "__main__":
    try:
        import invoke
    except ImportError as err:
        import argparse

        parser = argparse.ArgumentParser(prog=sys.argv[0], description="Installs tools needed to use github.com/mawillcockson/dotfiles")
        
        parser.add_argument("directory", default="~/projects/dotfiles", help="Directory that will contain the .venv directory for this environment")

        options = parser.parse_args()

        ensure_venv(options.dir)
    
    from invoke import task, Program, Config, Collection
    from invoke.config import merge_dicts
    import re
    namespace = Collection()
    for name in globals():
        if re.match(r"install.*", name) and type(globals()[name]).__name__ == "function":
            namespace.add_task(task(globals()[name]))
    own_name = Path(sys.argv[0]).stem
    class SetupConfig(Config):
        prefix = own_name

        @staticmethod
        def global_defaults():
            base_defaults = Config.global_defaults()
            overrides = {"tasks": {"collection_name": own_name}}
            return merge_dicts(base=base_defaults, updates=overrides)

    program = Program(name="setup", namespace=namespace, config_class=SetupConfig, version="0.0.1")
    program.run()