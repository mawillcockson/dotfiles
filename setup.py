#!/usr/bin/env python

import sys
from pathlib import Path

try:
    from invoke import task, Program, Config, Collection
    from invoke.config import merge_dicts
except ImportError as err:
    print(
        f"Cannot import invoke.\nPlease run install.py first, or report this error\n{err}",
        file=sys.stderr,
    )
    sys.exit(1)

# Make an explicit namespace
# We have our own Config subclass which defines the name of this file as the "prefix", which makes invoke search
# for config files, which can be in Python format http://docs.pyinvoke.org/en/1.3/concepts/configuration.html#format
# This means, invoke tries to load this file as a configuration file.
# Passing in an explicit namespace to the Program causes Program to skip load_collection(), which has Config try .py
# https://github.com/pyinvoke/invoke/blob/0cd18cf64e8e8d441ea6fe300d3b2651c90e5588/invoke/program.py#L447
namespace = Collection()


@task
def setup_gpg(ctx, clean=False):
    print(f"Setting up GnuPG{' and cleaning' if clean else ''}")
    ctx.run("uname -a")

namespace.add_task(setup_gpg)


# Drop the suffix, as invoke searches for a module with that name, and Python imports module_name.py files as modules
own_name = str(Path(sys.argv[0]).with_suffix(""))

# Subclass Config to override default collection_name to this file's name
class SetupConfig(Config):
    prefix = own_name

    @staticmethod
    def global_defaults():
        base_defaults = Config.global_defaults()
        overrides = {"tasks": {"collection_name": own_name}}
        return merge_dicts(base=base_defaults, updates=overrides)

program = Program(name="setup", namespace=namespace, config_class=SetupConfig, version="0.0.1")

if __name__ == "__main__":
    program.run()

# python -m pip install --user pipx
# python -m pipx ensurepath
# source ~/.profile
# pipx install dotdrop
# mkdir ~/projects
# git clone git@github.com:mawillcockson/dotfiles.git projects/dotfiles
# alias dotdrop='dotdrop --cfg=~/projects/dotfiles/config.yaml'
# dotdrop install

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
