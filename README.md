# [dotfiles][]

These are my personal dotfiles. I sometimes use them.

Critiques or improvements can be left in comments, issues, and PRs, or delivered by carrier pigeon.

## Setup

While the scripts in the [`dotfiles`](./dotfiles/) directory can sometimes be used by themselves, this repository uses [`dotdrop`][dotdrop] for managing the files, and requires [Python][] to be installed (with `pip`).

OS-specific Python installation instructions and other pre-requisites may be listed in one of the following:

 - [Debian](./INSTALL_debian.md)
 - [Arch Linux](./INSTALL_archlinux.md)
 - [Windows](./INSTALL_windows.md)

The remaining steps are platform independent.

### Continue

In a terminal session (PowerShell, bash, etc.):

```sh
python -c "import urllib.request as q,sys;r=q.urlopen('https://github.com/mawillcockson/dotfiles/raw/main/install_dotfiles.py');c=r.read().decode();r.close();sys.exit(exec(c))"
```

> _Note: `pip` is installed twice to make sure even very old versions of `pip` are upgraded to the latest_

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
