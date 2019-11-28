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

"""
The above is a good example of what this utility should be about, except for setting aliases.

This utility should not
# Install Oh-My-Zsh: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
# Install plug.vim as per dotdrop docs

That's best left up to dotdrop actions.

This utility should do the things to get dotdrop ready, and to get the other utilities in place that dotdrop will call.
It can download/install cURL, git, scoop, PowerShell Core, etc. The utilities required by dotdrop actions to bootstrap install.
It can also have a profile subcommand that is able to create a new dotdrop profile based on what functionality/features
are desired.
"""
