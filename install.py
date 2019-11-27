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
import venv

venv.EnvBuilder(clear=True, with_pip=True).create(str(current_dir/".venv"))

# Install invoke

# Handoff to invoke script
