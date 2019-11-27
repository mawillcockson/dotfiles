#!/usr/bin/env python

import sys

try:
    from invoke import task
except ImportError as err:
    print(f"Cannot import invoke.\nPlease run install.py first, or report this error\n{err}", file=sys.stderr)
    sys.exit(1)

@task
def setup_gpg(ctx, clean=False):
    print(f"Setting up GnuPG{' and cleaning' if clean else ''}")
    ctx.run("uname -a")


#python -m pip install --user pipx
#python -m pipx ensurepath
#source ~/.profile
#pipx install dotdrop
#mkdir ~/projects
#git clone git@github.com:mawillcockson/dotfiles.git projects/dotfiles
#alias dotdrop='dotdrop --cfg=~/projects/dotfiles/config.yaml'
#dotdrop install
