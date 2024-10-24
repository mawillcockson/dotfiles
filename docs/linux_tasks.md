# Tasks for changes that need to be made to Linux

- In nvim:
  - Find a way to tell if fonts are missing and issue a warning
    - Don't disable font changing, because it may be the detection method should be updated, but do add a hint on how to disable font changing temporarily
  - Find a way to tell when neovide or neovim can't set the font
- configure KeePass backup triggers
- A chezmoi data entry should be made and used to determine what kind of computer this is, and what should be installed
  - currently, there's the notion of 'bootstrap' or not, but I think this should be further expanded to a bevy of indicators, like os, hostname, etc
- `path_additions` should still warn about missing directories, but shouldn't decline to add them to `$PATH`
  - I'm thinking it could collect them in a `MISSING` environment variable, and append that to `$PATH` at the end of things

## completed

- Bootstrap nu and eget
  - could be done ~~while only depending on chezmoi's ability to make https requests: e.g. I need to know what the latest version of nu is, so I can make an externals entry for a "file" from the github api, and parse it using the fromJson function~~ using chezmoi's builtin GitHub functions <https://www.chezmoi.io/reference/templates/github-functions/>
- convert configure scripts for
  - git
  - gpg
- add apt-get as installation method, with the method for installing apt-get being just a test to see if it's installed already
- Ensure paths to e.g. eget-bin and  nvim are setup
  - KRunner should be able to find my apps
- Find a way to add `nvim` executable on $PATH
  - Maybe a symlink can be dropped into ~/.local/bin if the flatpak neovim is installed?
  - The symlink for nvim should only be created if `io.neovim.nvim` exists
- add installation scripts for
  - neovim
    - The place that the flatpak-ed neovim searching for init.vim needs to be symlinked to ~/.config/nvim
- add DejaVu Sans Mono NerdFont to system
- start-ssh
- add installation scripts for
  - there should be a consistent way to modify the apt configuration into the shape I want
  - firefox (custom apt repo)
  - kanata (udev rules, group membership, modprobe)
- find a place for the note
- Add fonts to the system
  - Maybe consider adding fonts to dotfiles repo?
    - Would have to encrypt ComicCode since it's licensed
- add eget methods for all essential software that needs to be up-to-date
- Environment variables:
  - NU_USE_IR should be set for the user
  - XDG_CONFIG_HOME should be set system-wide
- add installation scripts for
  - for pip: python3-pip needs to be installed, or a generic solution using <https://pip.pypa.io/en/stable/installation/#get-pip-py>
- Nvim font changing doesn't work
- starship notifications about amount of time a command took present as a window that steals focus
