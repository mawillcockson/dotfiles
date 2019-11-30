#!/usr/bin/env python

import sys

# Where are the dotfiles?

from pathlib import Path

current_dir = Path(".")

# If there isn't a "dotfiles" and a "README.md" file/folder in this directory, we're not in "dotfiles"
if not all(map(Path.exists, [current_dir / "dotfiles", current_dir / "README.md"])):
    print(
        f"This file needs to be run from the repository it's a part of, but it was run from\n{current_dir.cwd()}",
        file=sys.stderr,
    )
    sys.exit(1)

# Make a venv
venv_dir = (current_dir / ".venv").absolute()
setup_script = (current_dir / "setup.py").absolute()
print(f"Installing virtual environment for Python into '{venv_dir}'")

if venv_dir in Path(sys.executable).parents or venv_dir.exists():
    print(
        f"""It looks like there may already be a virtual environment installed in '{venv_dir}'.
This command creates a virtual environment from scratch.
If one is already created, but the command "dotdrop" can't be found, run

python {setup_script}

to finish the installation""",
        file=sys.stderr,
    )
    sys.exit(1)

import venv

venv.EnvBuilder(
    # clear=True,
    clear=False,
    with_pip=True,
).create(str(venv_dir))

# Install invoke
print(f"Installing invoke module into {venv_dir}")

from subprocess import run

venv_python = str((current_dir / ".venv" / "bin" / "python").absolute())
ret = run(
    [venv_python, "-m", "pip", "install", "invoke"], capture_output=True, text=True
)

if not ret.returncode == 0:
    print(f"Error installing invoke:\n{ret.stderr}", file=sys.stderr)
    sys.exit(1)

print(ret.stdout)

# Handoff to invoke script
print(f"Running rest of install with {setup_script}")

if not setup_script.exists():
    print(f"Cannot find file '{setup_script.name}'", file=sys.stderr)

run(
    [venv_python, str(setup_script)],
    stdin=sys.stdin,
    stdout=sys.stdout,
    stderr=sys.stderr,
    close_fds=True,
)
