# Windows

This assumes that this repository is being run directly on Windows, without using an emulation layer of alternate environment.

The only thing that needs to be installed is [Python][].

## Installing Python

[Python][] can be installed [from the microsoft store][python-ms-store], using a [download from the website][python-download], or using a package manager like [`scoop`][scoop].

The simplest way to install Python is by opening any command prompt, and typing `python`, which opens the Microsoft Store to Python.

I prefer `scoop`, which can be installed using [these instructions][scoop-install]. If this document isn't too out of date, those instructions hopefully look something like the following instructions.

First, we open a [PowerShel][] session, and set the execution policy, [which has security implications][ps-execpolicy].

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Next, we'll use `scoop` to install Python. While not necessary for Python, we also install [`aria2`][aria2] and [`git`][git] for `scoop`.

```powershell
scoop install aria2 git python
```

# Finish

If `python --version` returns information about the version of Python that was just installed, [continue with the rest of the instructions](./README.md#continue).



[python]: <https://www.python.org/>
[python-ms-store]: <https://docs.microsoft.com/en-us/windows/python/beginners#install-python>
[python-download]: <https://www.python.org/downloads/windows/>
[scoop]: <https://github.com/lukesampson/scoop>
[scoop-install]: <https://github.com/lukesampson/scoop/tree/3e55a70971c5ff0d035daa54ca5dfab95dfaaa1d#installation>
[powershell]: <https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-5.1>
[aria2]: <https://github.com/aria2/aria2>
[git]: <https://git-scm.com/>
[ps-execpolicy]: <https://docs.microsoft.com/en-us/PowerShell/module/microsoft.PowerShell.core/about/about_execution_policies?view=PowerShell-6>
