# [dotfiles][]

These are my personal dotfiles.

Critiques can be left in comments, issues, and PRs, or delivered by carrier pigeon.

# If this [README](./README.md) is still up to date

This repository uses [dotdrop][], and subsequently is a lot easier to use with [Python][] installed.

## Setup


For distribution-specific setup, see the appropriate INSTALL file:

 - [Debian](~/INSTALL_debian.md)

The config files contain calls to [cURL][], and will not work without it.

```
read -p "Install latest Python, git, and curl, then press enter"
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
[cURL]: <https://curl.haxx.se/>
[NeoVim]: <https://neovim.io/>
[tmux]: <https://github.com/tmux/tmux>
[gnupg2]: <https://gnupg.org/>
[oh-my-zsh]: <https://ohmyz.sh/>
[openbox]: <http://openbox.org>
[vim-plug]: <https://github.com/junegunn/vim-plug>
[tilda]: <https://github.com/lanoxx/tilda>
