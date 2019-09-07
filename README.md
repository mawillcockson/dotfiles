# [dotfiles][]

These are my personal dotfiles.

Critiques can be left in comments, issues, and PRs, or delivered by carrier pigeon.

# If this [README](./README.md) is still up to date

This repository uses [dotdrop][], and subsequently is a lot easier to use with [Python][] installed.

## Setup

In order to use this repository to set up an environment, the tools it depends on must be installed, namely [git][] and [python][]. Additionally, some setup of the environment is required prior to using this repository. _Note: In the future, this setup process may be automated by tooling included in this repository_

Each operating system has its own way of setting all of this up, which is hopefully described in its own file, listed here:

 - [Debian](./INSTALL_debian.md)
 - [Arch Linux](./INSTALL_archlinux.md)
 - [Windows](./INSTALL_windows.md)
 - [Cygwin](./INSTALL_cygwin.md)
 - [MSYS2 / Git Bash](./INSTALL_gitbash.md)
 - [Windows Subsystem for Linux](./INSTALL_wsl.md)
 - [FreeBSD](./INSTALL_freebsd.md)

Once those steps have been taken, the rest of the process is fairly straight-forward, and largely platform independent.

### Continue

The setup files contain calls to [cURL][], and will not work without it. The [distribution-specific setup files](./README.md#setup) should contain instructions on how to get this program so that the setup files in this repository know where to locate it, for each platform.

The rest of the setup process should be able to be completed by running the following commands in a console or shell session:

```
python -m pip install --user pipx
python -m pipx ensurepath
source ~/.profile
pipx install dotdrop
mkdir ~/projects
git clone git@github.com:mawillcockson/dotfiles.git projects/dotfiles
alias dotdrop='dotdrop --cfg=~/projects/dotfiles/config.yaml'
dotdrop install
```

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
[git]: <https://git-scm.com/>
[cURL]: <https://curl.haxx.se/>
[NeoVim]: <https://neovim.io/>
[tmux]: <https://github.com/tmux/tmux>
[gnupg2]: <https://gnupg.org/>
[oh-my-zsh]: <https://ohmyz.sh/>
[openbox]: <http://openbox.org>
[vim-plug]: <https://github.com/junegunn/vim-plug>
[tilda]: <https://github.com/lanoxx/tilda>
