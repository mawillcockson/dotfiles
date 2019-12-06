# If this [README](./README.md) is still up to date

These are my [dotfiles][], which I use to create an environment familiar to me.

This repository also includes the tools I use to put these dotfiles in useful places, and to configure other parts of the environment.

The dotfiles can be used by themselves, but a lot of them rely on the tool [dotdrop][] to change them depending on the platform this repository is used on.

[Setup](#setup) describes downloading, installing, and using these tools.

These instructions will occasionally require administrative access.

## Setup

This repository uses [dotdrop][], and requires [Python][] for installation and use.

These are the steps for installing [Python][] on different operating systems:

 - [Windows](./docs/INSTALL_windows.md)
 - [Debian](./docs/INSTALL_debian.md)

The files and tools included in this repository work well on the above platforms.

These are platforms I would like to support, but for which no work has been done.:

 - [Arch Linux](./INSTALL_archlinux.md)
 - [Cygwin](./INSTALL_cygwin.md)
 - [MSYS2 / Git Bash](./INSTALL_gitbash.md)
 - [Windows Subsystem for Linux](./INSTALL_wsl.md)
 - [FreeBSD](./INSTALL_freebsd.md)

Once [Python][] is installed, the instructions [below](#continue) describe how to download and use this repository.

### Continue

The rest of the setup process is automated by the [`install.py`](./install.py) script.

This file can be downloaded by [viewing it on GitHub and selecting `Save Page As...` or `Save as...`][install-installpy].

Alternatively, with [Python][] installed, the following command will download the file:

```sh
python -c "import sys;raise SystemExit('Python 3.7 or higher required') if sys.version_info>=(3,7) else '';from urllib.request import urlopen as o;r=o('https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py').read();f=open('install.py','wb');f.write(r);f.close()"
```

To start the installation, run the file, double-click it, or, if the above command was used to download the file, from the same terminal type the following command:

```sh
python install.py
```

This should pop up with a screen that looks like the following

![First run installation][screenshot]

All of the rest of the instructions should be provided by [`install.py`](./install.py).

As part of the setup, the script will attempt to install [Python packages][python-packages] and [dotdrop][], and will create a `.venv` folder in a temporary directory until the environment is configured to allow for their permanent installation.

If the installation is interrupted, as long as `install.py` was downloaded, the installation can be restarted by rerunning that file.

# Feedback

Critiques can be left in [comments][], [issues][], and [PRs][], or delivered by [carrier pigeon][pigeon].


[dotfiles]: <https://wiki.archlinux.org/index.php/Dotfiles>
[dotdrop]: <https://github.com/deadc0de6/dotdrop>
[Python]: <https://www.python.org/>
[install-installpy]: <https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py>
[repo-archive]: <https://github.com/mawillcockson/dotfiles/archive/dev.zip>
[screenshot]: <https://images.unsplash.com/photo-1519125323398-675f0ddb6308?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1200&q=80>
[python-packages]: <https://pypi.org/help/#packages>
[comments]: <https://github.com/login?return_to=https%3A%2F%2Fgithub.com%2Fmawillcockson%2Fdotfiles%2Fcommit%2Fa6d9cfffe5e2687c5b1a8ebbef11db12ea00060b%3F_pjax%3D%2523js-repo-pjax-container>
[issues]: <https://github.com/mawillcockson/dotfiles/issues/new>
[prs]: <https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request>
[pigeon]: <https://tools.ietf.org/html/rfc6214>