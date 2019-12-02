# Arch/Manjaro

This is needed to allow ansible to build:

```sh
ln -s /usr/lib/libffi-3.2.1/include/ffi*.h /usr/include
```

When Python is updated to a new major version (`3.7 -> 3.8`) `pipx` has to be refreshed:

```bash
# Save list of packages
pipx list | grep -Eos 'package [[:alnum:]-]+' | sed -e 's/package //' > pipx_packages
# Uninstall pipx
python -m pip uninstall pipx
# Remove pipx venvs
rm -r ~/.local/pipx
# Reinstall pipx with new python
python -m pip install --user pipx
# Reinstall pipx packages
for pkg in $( <pipx_packages ); do
    pipx install $pkg
done
# Delete saved list of packages
rm pipx_packages
```

# Debian install

## Add created user to sudo group

During installation, the root account password is set, and a "normal" user is created. This normal user is going to be the one we use day-to-day, and I prefer to do system administration from this account through sudo for sudo's auditing capabilities.

So, we must make sure this user is setup for these tasks. To make those changes, it's easier to log in as root to do them in bulk.

Login as root.

It's a good bet that the user created during install was assigned uid `1000`. If not, sub in correct username.

```
export REG_USER=$(awk -F ':' '$3 == 1000' /etc/passwd | sed -E 's/([a-z]+).*$/\1/')
usermod -a -G sudo "${REG_USER}"
```

## Install packages

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

## Set up gnupg

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

## Prepare dotdrop installation

Clone this repository, and set an alias for python3 as Debian defaults to python2.

```
mkdir -p ~/projects
git clone --depth 1 --single-branch git@github.com:mawillcockson/dotfiles.git ~/projects/dotfiles
alias python=python3
```

## Done

May continue with [rest of setup](~/README.md)



[apt-sources]: <https://wiki.debian.org/SourcesList>


# Windows install

## The Windows hurdle

By far the most difficult setup has been Windows, and forcing the use of command-line Unix tools.

It would probably have been easier to have used GUI tools built for windows, as opposed to having attempted to lift the entire setup from other operating systems, and transplant it to Windows.

## Getting the repository

In order to get and use the repository we need [`git`][git], [`gpg`][gnupg], and [`python`][python].

All three of these can be downloaded and installed using [scoop][], which we will download and install in a following section.

We also need a program to help automate downloading and managing all these programs. In this case, we'll use [Windows PowerShell][PowerShell].

Unless noted, all commands are run in order, in one [PowerShell][] session. Some variables may be set in one section, and then used in later sections, and the later sections may not work if the PowerShell session is closed and reopened.

### [PowerShell Core][pscore6]

While not strictly necessary, having the latest and greatest [PowerShell Core][pscore6] would be nice. This process does require administrative privaleges, currently, as it install this for all users.

To get PowerShell Core, run the following commands from PowerShell:

```
((iwr -useb https://api.github.com/repos/PowerShell/PowerShell/releases/latest).Content -split "," | Select-String -Pattern "https.*x64.msi").Line -match "https.*msi" | %{ iwr -useb $Matches.0 -outf pwsh_x64.msi }
msiexec /package pwsh_x64.msi /qB ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1
```

Click on the dialogue box that pops up, asking for permission to perform the installation. All of the options for the installation should have been set by the command, and so no dialogue boxes should pop up, and once the installation is finished, any windows should close automatically.

Once done, the new version of powershell should be available by running the command `pwsh`, however the installation process did not update the current session with information on where to find the new program, [so we'll do that now][pwsh-reload]:

```
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

Then we can run:

```
pwsh
```

If any part of this process did not work, or produced errors, or if the account does not have administrative privaledges, replace any use of `pwsh` with `powershell` in all further sections.

### [scoop][]

We will use [scoop][] for package management.

In order to get [scoop][], we will use the [the installation steps given in the README][scoop-installation]. If this links to something that is old, check the [main repository README][scoop-readme] for up-to-date instructions.

In order to be able install [scoop][], we need to set the execution policy in PowerShell. [This has security implications][ps-execpolicy].

To do this, in the same PowerShell session, run:

```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

A short message should pop up. Agree by typing `Y`, then pressing <kbd>Enter</kbd>.  
_Note: If nothing pops up, the execution policy is already set appropriately_

Then, we will install scoop:

```
iwr -useb get.scoop.sh | iex
```

Next, we'll install the programs scoop needs for the additional features we require, as well as the programs we need.

```
scoop install aria2 git
scoop bucket add extras
scoop install gnupg wsl-ssh-pageant
```

### Testing [GnuPG][]

Before we begin configuring [GnuPG][], we need to make sure it can read our OpenPGP-compatible card or security key.

To test this, first insert the key/card, and gnupg should see it:

```
gpg-connect-agent updatestartuptty /bye
gpg --card-status
gpg-connect-agent "keyinfo --list" /bye
```

_Note: Sometimes,_ `gpg-agent` _might fail to start, and show messages like:_

```
gpg-connect-agent: waiting for the agent to come up ... (5s)
gpg-connect-agent: waiting for the agent to come up ... (4s)
gpg-connect-agent: waiting for the agent to come up ... (3s)
gpg-connect-agent: waiting for the agent to come up ... (2s)
gpg-connect-agent: waiting for the agent to come up ... (1s)
gpg-connect-agent: can't connect to the agent: IPC connect call failed
gpg-connect-agent: error sending standard options: No agent running
```

_Just rerun the_ `gpg-connect-agent updatestartuptty /bye` _command_.

### Configuring [GnuPG][]

Now that we know that `gpg` can see the key/card, we can [configure `gpg-agent`][configure-gpg-agent] [with PuTTY support][gpg-putty], then [restart `gpg-agent`][restart-gpg-agent], as described in this section.

Instead of regular SSH support, I chose [PuTTY][] support as the tooling for connecting the [OpenSSH suite built into Windows 10][win32-openssh] to gnupg [is currently one of the only avenues to get the two to talk][openssh-gpg-connect], and it allows the use of PuTTY with the same authentication mechanism.

One thing to note as a result of this setup is that, since [OpenSSH has been shipped with Windows 10 since autumn 2018][windows-ssh-info], this setup won't work exactly as expected on any version prior to this, or versions lacking this OpenSSH suite.

To enable putty support in `gpg-agent`, either edit the file indicated by the following command (this file might not exist and may need to be created):

```
(gpgconf --list-dirs socketdir) + "\gpg-agent.conf"
```

And put the string `enable-putty-support` on a single line in the file, or run the following command:

`echo "enable-putty-support:0:1" | gpgconf --change-options gpg-agent`

Either way, putty support is permanently enabled.

Now that putty support is enabled, reload `gpg-agent`:

```
gpg-connect-agent reloadagent /bye
```

### Bridge GnuPG and Win32-OpenSSH

The OpenSSH suite shipped with Windows listens on a [named pipe][named-pipe], instead of a [Unix domain socket][af-unix], which is what gnupg uses, so we need a program to shuttle between the two.

`wsl-ssh-pageant` can bridge `ssh` and `gpg-agent`.

The [default name][default-win-pipe] of the [named pipe][named-pipe] is `\\.\pipe\openssh-ssh-agent`, but we'll use a different one to make things more confusing:

```
Set-Item -Path Env:SSH_AUTH_SOCK -Value "\\.\pipe\ssh-pageant"
[Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $env:SSH_AUTH_SOCK, 'User')
```

Unfortunately, for reasons not known to me, `wsl-ssh-pageant` doesn't like being second to the party when using a socket file. In other words, `wsl-ssh-pageant` gives the following error if `gpg-agent` is already running before `wsl-ssh-pageant` is started:

```
Could not open socket $Env:USERPROFILE\AppData\Roaming\gnupg\S.gpg-agent.ssh, error 'listen unix $Env:USERPROFILE\AppData\Roaming\gnupg\S.gpg-agent.ssh: bind: Only one usage of each socket address (protocol/network address/port) is normally permitted.'
```

So we stop `gpg-agent`:

```
gpg-connect-agent killagent /bye
```

We'll bring it back after we start `wsl-ssh-pageant`.

Before starting `wsl-ssh-pageant`, it's important to note that the command below runs `wsl-ssh-pageant` in its own background process, which needs to be running each time `git` or `ssh` need to talk with `gpg-agent`. A step for setting this command to run on login is pending.

The good news is that this process is detached from PowerShell, and closing PowerShell will not close this process, or prevent `wsl-ssh-pageant` from working with other PowerShell or console sessions.

Also, having `wsl-ssh-pageant` running does not appear to impede the use of both PuTTY and Windows' native `ssh` client from both using the keys stored on the key/card.

So to start `wsl-ssh-pageant`, run:

```
pwsh -Command "start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-systray','-winssh','ssh-pageant','-wsl',(gpgconf --list-dirs agent-ssh-socket)) -WindowStyle hidden"
```

The success of this command is indicated by a new icon appearing in the system tray.

If the icon pops up briefly, before closing by itself, or does not appear at all, something is wrong. The error can be viewed by running the command in the current console, as opposed to spawning a new process:

```
wsl-ssh-pageant.exe -systray -winssh "\\.\pipe\ssh-pageant" -wsl (gpgconf --list-dirs agent-ssh-socket)
```

Finally, if `wsl-ssh-pageant` is running, we can restart `gpg-agent`:

```
gpg-connect-agent updatestartuptty /bye
```

### Testing and finale

Now `ssh` should be able to see the keys on the key/card.

To test this, make sure the key/card is inserted, and run:

`ssh-add -L`

This is the most important part, and if this shows an error message about connecting to an agent, a bad response from an agent, or just nothing, then please make prolific use of your search engine of choice.

To download the repository, `git` should be able to talk with GitHub. To test this, [the following should print out a short message][github-test-ssh]:

```
ssh -T git@github.com
```

To then get `git` to be able to use the `ssh` client configured for interacting with `gpg-agent`, [set the `GIT_SSH` environment variable][git-ssh]:

```
Set-Item -Path Env:GIT_SSH -Value (scoop which ssh)
[Environment]::SetEnvironmentVariable('GIT_SSH', $env:GIT_SSH, 'User')
```

To get `git` to use the correct `gpg` program, [set that in the global git config][git-gpg]:

```
git config --global gpg.program (scoop which gpg)
```

## Return to regular install

Now that all that's done, we can [continue with the installation.](./README.md#setup)



[git]: <https://git-scm.com/>
[gnupg]: <https://www.gnupg.org/>
[python]: <https://www.python.org>
[ssh]: <https://en.wikipedia.org/wiki/Secure_Shell>
[scoop-installation]: <https://github.com/lukesampson/scoop/tree/3e55a70971c5ff0d035daa54ca5dfab95dfaaa1d#installation>
[scoop-readme]: <https://github.com/lukesampson/scoop/blob/master/README.md>
[OpenSSH]: <https://www.openssh.com/>
[af-unix]: <http://man7.org/linux/man-pages/man7/unix.7.html>
[powershell]: <https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-5.1>
[scoop]: <https://github.com/lukesampson/scoop>
[pscore6]: <https://aka.ms/pscore6>
[pwsh-reload]: <https://stackoverflow.com/a/31845512>
[ps-execpolicy]: <https://docs.microsoft.com/en-us/PowerShell/module/microsoft.PowerShell.core/about/about_execution_policies?view=PowerShell-6>
[configure-gpg-agent]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Configuration.html>
[restart-gpg-agent]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Protocol.html#Agent-Protocol>
[windows-ssh-info]: <https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview>
[gpg-putty]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html#option-_002d_002denable_002dssh_002dsupport>
[PuTTY]: <https://www.chiark.greenend.org.uk/~sgtatham/putty/>
[win32-openssh]: <https://github.com/PowerShell/openssh-portable>
[openssh-gpg-connect]: <https://github.com/PowerShell/Win32-OpenSSH/issues/827>
[default-win-pipe]: <https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297>
[named-pipe]: <https://docs.microsoft.com/en-us/windows/win32/ipc/named-pipes>
[github-test-ssh]: <https://help.github.com/en/articles/testing-your-ssh-connection>
[git-ssh]: <https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables#_miscellaneous>
[git-gpg]: <https://stackoverflow.com/a/43393650>


# Notes for Debian

Need to check if the default install still doesn't add the secondary user to the `sudo` group, or otherwise give it access to using `sudo`.

# Notes for Python

Upgrading major versions of Python requires care. All Python tools and libraries need to have their state saved, and then their caches cleared and to be reinstalled:

- pipenv Pipfile and caches
- pipx as in previous note

---

I think I would want the setup script(s) to ask about which profile should be used, and continue on their way if yes, and if no, walk through buiding a custom profile, with questions asking about software setups instead of individual files:

- vim or nvim?
  - if nvim, full vim IDE or just simple `set ts=4 sw=4 expandtab` etc?
- pipenv?
- tmux?
- install my frequently used packages and apps?

I think it'd be handy to have it be able to start from a list of profiles, as well, defaulting to "minimal".

Once the profile is built, `dotdrop` can be run to populate everything.

I think I'd want a few utility scripts to be able to do more complex things, like configuring GnuPG on various platforms, and allow these to be run independently as best as possible, possibly calling dotdrop with custom options to place just the files those actions require.

I also would want an uninstall.py that is able to remove all the files added to the system, replacing them with the `.dotdropbak` versions where possible, even so far as to `git clean -f` the repo (mostly so I have an excuse to double fork a shell process so the uninstaller can uninstall itself, along with the Python executable it's using to run).

The extreme example is to track which files are opened in anything except read mode using Python's auditing system and setting a hook for `open` events: <https://docs.python.org/3/library/audit_events.html#audit-events-table>

This could be used to at least keep track of which files are written, which files are appended to, etc, so during the uninstall, all touched files can be listed.

One advantage of using dotdrop for file manipulation is we can `remove` files.

It would be ideal to have an uninstall that's very good at uninstalling.

# On Windows

`scoop` python uses version-specific script folders in appdata: `appdata\roaming\python\python38\scripts\`

These folders need to be added to `$Env:PATH` in order to work.

Also, be careful with conficts if Cygwin is in the `$Env:PATH`:

```powershell
PS C:\Users\mawil> pipx
Program 'pipx' failed to run: No application is associated with the specified file for this operationAt line:1 char:1   + pipx
+ ~~~~.
At line:1 char:1
+ pipx
+ ~~~~
+ CategoryInfo          : ResourceUnavailable: (:) [], ApplicationFailedException
+ FullyQualifiedErrorId : NativeCommandFailed

PS C:\Users\mawil> pipx.exe
usage: pipx [-h] [--version]
            {install,inject,upgrade,upgrade-all,uninstall,uninstall-all,reinstall-all,list,run,runpip,ensurepath,completions}
            ...

Install and execute apps from Python packages.
```

The `greenlet` package required by the `neovim` python package require [Build Tools for Visua Studio](https://visualstudio.microsoft.com/downloads/) before it can be built.

The Build Tools must be downloaded and installed before `pipenv install neovim`.

Currently, there are lots of ways to detect which platform is being used.

The obvious one would be to use things from the `platform`, `os`, and `sys` modules in the Python standard library, but I imagine these don't capture the true nuance of the beast.

The platform module first tries `os.name`, and if that fails, [uses the `subprocess` module to run commands on the system](https://github.com/python/cpython/blob/master/Lib/platform.py#L766). One of the comments in there points to [a very old website that thankfully was successfully captured exactly _once_ by WayBack in 2009](https://web.archive.org/web/20090829052909/http://www.geocities.com/rick_lively/MANUALS/ENV/MSWIN/PROCESSI.HTM). Seriously, [the internet is mercurial and ephemeral](https://xkcd.com/1909/).

[The docs](https://docs.python.org/3.7/library/platform.html#platform.linux_distribution) suggest the [`distro`](https://github.com/nir0s/distro) module for Linux differentiation, but it's [Windows, MacOS](https://github.com/nir0s/distro/issues/177), and [BSD](https://github.com/nir0s/distro/blob/cdfe85d15bd366820db6a1cfdc6cf9a0a5de7e37/distro.py#L163) detection leave gaps.

Ansible [bundles `distro`](https://github.com/ansible/ansible/tree/106c7885b86b42223c07851dccaeb8de25c19fc4/lib/ansible/module_utils/distro), but also uses its own custom distro-file parsing to augment and fill in gaps from `platform`, [but implements its own slightly different parsing](https://github.com/ansible/ansible/blob/1d91e0311918d63f1aecfc6ce67596f4808a4976/lib/ansible/module_utils/facts/system/distribution.py#L496), it seems.

SaltStack [relies on the `platform` module](https://github.com/saltstack/salt/blob/cc913911f96b792e1c9fc9bb2f665842d41f4da4/salt/grains/core.py#L1624), but also has some very nice platform detection, including [interesting Windows hardware detection](https://github.com/saltstack/salt/blob/cc913911f96b792e1c9fc9bb2f665842d41f4da4/salt/grains/core.py#L1248) with technet links sourcing the methodology.

Most importantly, the `venv` module chooses whether to call the directory in which it stores `python.exe` `Scripts` or `bin` by [checking `sys.platform == "win32"`](https://github.com/python/cpython/blob/1df65f7c6c00dfae9286c7a58e1b3803e3af33e5/Lib/venv/__init__.py#L120), so we gotta use that to make sure we find the correct directories.

# Direction

I think there's a couple problems that can best be solved architecturally. Plus a general reorganization of the repository.

So the first problem is that I want to use the `setup.py` file as a single file that can be run, that expects `invoke` to be available.

While it's not a big deal to try to recreate the things that `Scripts/Activate.ps1` does, and add a `VIRTUAL_ENV` environment variable, and add `.venv` to the front of `$Env:PATH`, it seems finicky.

I think a better solution would be to augment `install.py` to be able to do this:

```sh
$ python -c 'from urllib.request import urlopen;exec(urlopen("https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py").read().decode("utf-8"))'
```

This would complicate things, as my desired end state would be to have the repository downloaded and "run".

I would probably want it to be able to take an argument, so I'd probably change it to look like:

```sh
$ python -c 'from urllib.request import urlopen;r=urlopen("https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py").read();f=open("install.py","wb");f.write(r);f.close();print(r.decode("utf-8"))' | python - dotfiles
$ # This is equivalent to
$ curl https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py | tee install.py | python - dotfiles
$ # but some platforms do not have cURL in their base install, and don't have a platform to easily install it, namely Windows
$ # or, in two steps
$ python -c 'from urllib.request import urlopen;r=urlopen("https://raw.githubusercontent.com/mawillcockson/dotfiles/dev/install.py").read();f=open("install.py","wb");f.write(r);f.close()'
$ python install.py dotfiles
```

That way, it can be rerun with just `python install.py dotfiles`, and can more easily take arguments.

The second problem is that I would want to be able to call a utility from any context to setup `GnuPG`. On other platforms, this is trivial to do, but in Windows, best that can be done is add a script to the path. I would like the way its interacted with to be (largely) platform independent, so I believe that behooves me to follow [these instructions from `invoke`](https://docs.pyinvoke.org/en/1.3/concepts/library.html) and make my own cli tool that can be installed with a `pipx install git+https://github.com/mawillcockson.dotfiles@master#egg=tool_name&subdirectory=tool_name` to make sure it's updated properly, outside of the repository version.

This has the problem that the `install.py` file must _at least_ install `pipx` and `git`.

I mean, it's assumed the repository is downloaded somehow already. It might be better to just install locally:

```sh
pipx install dotfiles/tool_name
```

This has the advantage of only needing to install pipx, which can be done with a (supposedly) platform independent `python -m pip install --user -U pipx`. I would, though, need to actually install `git` anyways, as the only way someone would get the repo is by downloading a zip off GitHub. The tool would then need to be able to convert it to a repo where `git pull` updates everything, with nice post-pull hooks to `pipx update-all` and such.

It might be worth it on the use side to automate installing `git`, as that'd be challenging, and would mean the `install.py` script would have the framework in place for feature creep. Also, the repo could be cloned on its own, without having to munge with adding it after.

I think I'll go the easy route and use the stdlib `platform` module to only implement on the platforms I need 🤷‍♀️

This is good to understand: <https://medium.com/python-pandemonium/a-trap-of-shell-true-in-the-subprocess-module-6db7fc66cdfd>

The preferred way to programmatically import modules from files is [described in the docs for `importlib`!](https://docs.python.org/3/library/importlib.html#importing-a-source-file-directly)

Also, if we want to check if a module is importable, [we can do it this way](https://docs.python.org/3/library/importlib.html#checking-if-a-module-can-be-imported), but at least in the case ov `invoke`, we actually do want to import it, so `try: ... catch Import Error: ...` does work.