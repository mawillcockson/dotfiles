# Debian

The standard [Debian installation process][install-debian] sets the root password and creates a second, non-root user.

These dotfiles are designed to be used from a regular, non-root account. Additionally, the more a root account is modified, the greater the chance those modifications will interfere with using the account for resolving problems.

# Install [Python][]

Debian does come with `python3`, but is missing `pip` and `venv`. These can be installed with the following:

```sh
apt-get install python3-{pip,venv}
```

Using `apt-get` requires administrative privileges. `su` or `sudo` can be used to run the above command as `root`.

# Finish

Now that `python -m pip --version` works, [the rest of the instructions can be followed](./README.md#continue).



[install-debian]: <
[python]
