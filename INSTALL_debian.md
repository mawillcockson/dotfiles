# Add created user to sudo group

Login as root

```
export REG_USER=$(awk -F ':' '$3 == 1000' /etc/passwd | sed -E 's/([a-z]+).*$/\1/')
usermod -a -G sudo "${REG_USER}"
```

It's a good bet that the user created during install was assigned uid `1000`. If not, sub in correct username.

# Install packages

 - neovim
 - curl
 - gnupg2
 - scdaemon
 - pcscd
 - keepass2
 - xdotool
 - tmux
 - python3-pip (Debian does come with python3, but it doesn't have pip)
 - python3-venv
 - git

Edit the [`sources.list`][apt-sources] file to add the repositories for keepass and other tools.

`sed -E 's/(^deb.*$)/\1 contrib non-free/' /etc/apt/sources.list > /etc/apt/sources.list`

Update package lists and install tmux

`apt-get update && apt-get install tmux -y`

In one tmux pane, install required package before upgrading system, and open another pane as the regular user for when the tools are installed so the following steps can be performed as the system is upgraded.
The pane installing and upgrading will automatically close once the process finishes, even if an error occured.

`tmux -2 new-session "su -l ${REG_USER}" \; split-window 'apt-get install neovim curl gnupg2 scdaemon pcscd keepass2 xdotool python3-pip python3-venv git && apt-get dist-upgrade -y'`

# Set up gnupg

Download PGP key

`gpg --recv-key "C00F E73F 1CC4 39D6 2D7E  C571 AA5E 96DD 8DD1 9233"`

Download suggested config

`curl -Ls https://raw.githubusercontent.com/drduh/config/master/gpg.conf > ~/.gnupg/gpg.conf`

Mark key as ultimately trusted

`gpg --edit-key matthew`

and on the following screen

```
trust
5
y
quit
```

Start agent with SSH support

`gpg-agent --enable-ssh-support && export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)`

Should now see output for both of the following commands

```
gpg --card-status
ssh-add -L
```

# Prepare dotdrop installation

Clone this repository, and set an alias for python3 as Debian defaults to python2.

```
mkdir -p ~/projects
git clone --depth 1 --single-branch git@github.com:mawillcockson/dotfiles.git ~/projects/dotfiles
alias python=python3
```

# Done

May continue with [rest of setup](~/README.md)



[apt-sources]: <https://wiki.debian.org/SourcesList>
