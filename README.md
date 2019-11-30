# [dotfiles][]

These are my personal dotfiles.

Critiques can be left in comments, issues, and PRs, or delivered by carrier pigeon.

# If this [README](./README.md) is still up to date

This repository uses [dotdrop][], and requires Python.

## Setup

In order to use this repository to set up an environment, the tools it depends on must be installed, namely [Python][].

Each operating system has its own way of setting all of this up, which is hopefully described in its own file, listed here:


 - [Windows](./INSTALL_windows.md)
 - [Debian](./INSTALL_debian.md)

These are platforms I would like to support:

 - [Arch Linux](./INSTALL_archlinux.md)
 - [Cygwin](./INSTALL_cygwin.md)
 - [MSYS2 / Git Bash](./INSTALL_gitbash.md)
 - [Windows Subsystem for Linux](./INSTALL_wsl.md)
 - [FreeBSD](./INSTALL_freebsd.md)

Once those steps have been taken, the rest of the process is fairly straight-forward, and largely platform independent.

### Continue

The rest of the setup process is automated by the [`install.py`](./install.py) script, which can now be executed, by either typing `python install.py` at a terminal, or by double-clicking the file.

This script will attempt to install and run [`dotdrop`][dotdrop]. It uses [Python packages][python-packages] to do this, and will create a `.venv` folder in this downloaded repository to store them.

Other packages will be installed, and the environment will be changed to align with my preferences. To use only the dotfiles, install and use `dotdrop` without running [`install.py`](./install.py). Unfortunately, some of the dotfiles have actions that set environment variables and modify existing files to make the dotfile useful.

## Contents

I use the following software:

- [NeoVim][]
- [tmux][]
- [gnupg2][]
- [oh-my-zsh][]
- Linux
  - [openbox][]
  - [vim-plug][]
  - [tilda][]

[dotfiles]: <https://wiki.archlinux.org/index.php/Dotfiles>
[dotdrop]: <https://github.com/deadc0de6/dotdrop>
[Python]: <https://www.python.org/>
[python-packages]: <https://pypi.org/help/#packages>
[NeoVim]: <https://neovim.io/>
[tmux]: <https://github.com/tmux/tmux>
[gnupg2]: <https://gnupg.org/>
[oh-my-zsh]: <https://ohmyz.sh/>
[openbox]: <http://openbox.org>
[vim-plug]: <https://github.com/junegunn/vim-plug>
[tilda]: <https://github.com/lanoxx/tilda>
