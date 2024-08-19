# Tasks for changes that need to be made to Linux

- Nvim font changing doesn't work
  - Find a way to tell if fonts are missing and issue a warning
    - Don't disable font changing, because it may be the detection method should be updated, but do add a hint on how to disable font changing temporarily
  - Find a way to tell when neovide or neovim can't set the font
  - Add fonts to the system from OneDrive
    - Maybe consider adding fonts to dotfiles repo?
      - Would have to encrypt ComicCode since it's licensed
- Bootstrap nu and eget
  - could be done ~~while only depending on chezmoi's ability to make https requests: e.g. I need to know what the latest version of nu is, so I can make an externals entry for a "file" from the github api, and parse it using the fromJson function~~ using chezmoi's builtin GitHub functions <https://www.chezmoi.io/reference/templates/github-functions/>
- add eget methods for all essential software that needs to be up-to-date
- add apt-get as installation method, with the method for installing apt-get being just a test to see if it's installed already
- add installation scripts for
  - kanata (udev rules, group membership, modprobe)
  - firefox (custom apt repo)
  - keepass (needs mono-complete, download plugins)
  - for pip: python3-pip needs to be installed, or a generic solution using <https://pip.pypa.io/en/stable/installation/#get-pip-py>
- configure KeePass backup triggers
- Ensure paths to e.g. eget-bin and  nvim are setup
  - KRunner should be able to find my apps
- start-ssh
- convert configure scripts for
  - git
  - gpg
- starship notifications about amount of time a command took present as a window that steals focus
- A chezmoi data entry should be made and used to determine what kind of computer this is, and what should be installed
  - currently, there's the notion of 'bootstrap' or not, but I think this should be further expanded to a bevy of indicators, like os, hostname, etc

## non-linux

- codify temporary ncspot login-flow