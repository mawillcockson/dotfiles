# [dotfiles][]

These are my personal dotfiles. I sometimes use them.

Critiques or improvements can be left in comments, issues, and PRs, or delivered by carrier pigeon.

## Setup

While the files in the [`dotfiles`](./dotfiles/) directory can sometimes be
used by themselves, this repository uses ~~[`dotdrop`][dotdrop]~~
[`chezmoi`][chezmoi] for managing the files, and is designed to work with that.

### One-liners

The dotfiles can be installed at the same time as [`chezmoi`][chezmoi].

In PowerShell, it would be:

```powershell
iex "&{$(irm -useb 'https://get.chezmoi.io/ps1')} -b ~/.local/bin init mawillcockson --apply --depth 1 --source ~/projects/dotfiles"
```

In POSIX shell it would be:

```sh
sh -c "$(curl -fsSL https://get.chezmoi.io | sh -s -- -b ~/.local/bin init mawillcockson --apply --depth 1 --source ~/projects/dotfiles)"
```

> _Note: on Windows, if there's an SSL error, run `iwr -useb https://github.com`, then try again_

Alternatively, [`chezmoi`][] can be installed separately, and then the following command can be run:

```sh
chezmoi init mawillcockson --apply --depth 1 --source ~/projects/dotfiles
```

I use some of the tools on their own often enough that I'm including a few oneliners for them here:

- kanata:

```powershell
powershell -ex remotesigned "irm -useb https://github.com/mawillcockson/dotfiles/raw/main/docs/install_kanata.ps1 | iex"
```

## Contents

The following software features prominently in my configs:

- [nushell][]
- [NeoVim][]
- [gnupg2][]
- Linux
  - [tmux][]

[dotfiles]: <https://wiki.archlinux.org/index.php/Dotfiles>
[dotdrop]: <https://github.com/deadc0de6/dotdrop>
[chezmoi]: <https://www.chezmoi.io/>
[NeoVim]: <https://neovim.io/>
[tmux]: <https://github.com/tmux/tmux>
[gnupg2]: <https://gnupg.org/>
[nushell]: <https://www.nushell.sh/>
