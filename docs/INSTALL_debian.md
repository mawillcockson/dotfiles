# Debian

The standard [Debian installation process][install-debian] sets the root password and creates a second, non-root user.

These dotfiles are designed to be used from a regular, non-root account. Additionally, the more a root account is modified, the greater the chance those modifications will interfere with using the account for resolving problems.

# Install [Python][]

Debian may come with `python3`, but is missing `pip` and `venv`. These can be installed with the following:

```sh
apt-get install python3-{pip,venv}
```

Using `apt-get` requires administrative privileges. `su` or `sudo` can be used to run the above command as `root`.

# Testing

Now that python has the appropriate packages, we can test to make sure they're installed and usable by `python`. The below command should print out information about which pip was installed:

```sh
python -m pip --version
```

If this works, continue to [Finish](#finish).

If an error like below was printed out:

```text
/usr/bin/python2: No module named pip
```

We have two options:

1. Change the default version of [Python][] on the system
2. Replace `python` with `python3` in all of the instructions

Option (1) requires `sudo` privileges, or access to `su`. If neither of these is available, option (2) is the only choise, and all appearances of `python` in any further instructions must be replaced with `python3`.

If `sudo` or `su` is available, we'll use [Debian's alternatives system][deb-alternatives]. To get a root shell to run these commands, run either `su` or `sudo -i`, whichever works.

Then, check to see if the current `python` is a [symbolic link][symlink]:

```sh
file -h $(which python)
```

This should print out something like the following:

```sh
root@computer:~# file -h $(which python)
/usr/bin/python: symbolic link to /usr/bin/python2
```

Above, `/usr/bin/python` is the current location of `python`, and `/usr/bin/python2` is what it currently points at. Now that we know this information, we'll use it in the below command. Replace `/usr/bin/python` and `/usr/bin/python2` with the names from your computer:

```sh
update-alternatives --install /usr/bin/python python /usr/bin/python2 1
```

Now we'll set `python3` as the default:

```sh
update-alternatives --install /usr/bin/python python $(which python3) 2
```

We can check to see if our configuration changes were applied:

```sh
update-alternatives --config python
```

This should print out something like the following, with information appropriate to your system:

```text
There are 2 choices for the alternative python (providing /usr/bin/python).

  Selection    Path              Priority   Status
------------------------------------------------------------
* 0            /usr/bin/python3   2         auto mode
  1            /usr/bin/python2   1         manual mode
  2            /usr/bin/python3   2         manual mode

Press <enter> to keep the current choice[*], or type selection number:
```

Pressing <kbd>Enter</kbd> without typing anything will leave the default as `python3`. To change the default at a later time, run the above command, and select `1` to set `python2` as the default.

If the above didn't work, option (2) is the only route. Either way, continue to [Finish](#finish)

## Finish

To test if `python`, `pip`, and `venv` were installed correctly, we can run the following commands:

```sh
python -c "import sys;assert(sys.version_info>=(3,7))" >/dev/null 2>&1 && echo python installed || echo python not working
python -m pip -V >/dev/null 2>&1 && echo pip installed || echo pip not installed
python -m venv -h >/dev/null 2>&1 && echo venv installed || echo venv not installed
```

Now that we know Python works, [the rest of the instructions can be followed](./README.md#continue).



[install-debian]: <https://www.debian.org/releases/stable/installmanual>
[deb-alternatives]: <https://wiki.debian.org/DebianAlternatives>
[python]: <https://python.org>
[symlink]: <https://wiki.debian.org/SymLink>
