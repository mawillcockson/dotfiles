# The Windows hurdle

By far the most difficult setup has been Windows, and forcing the use of command-line Unix tools.

It would probably be easier to use GUI tools built for windows, as opposed to lifting the entire setup from other operating systems, and transplanting it to Windows.

# Getting the repository

In order to get the repository we need [git][] and [gnupg][].

Windows now comes with [OpenSSH][], but it listens on a [named pipe][named-pipe], not a [Unix domain socket][af-unix], which is what gnupg uses, so we need a program to shuttle between the two.

We also need a program to help automate downloading and managing all these programs.

To get all of this set up, we'll use [Windows PowerShell][PowerShell].

Unless noted, all commands are run in order, in one [PowerShell][] session.

## [PowerShell Core 6][pscore6]

While not strictly necessary, having the latest and greatest [PowerShell Core 6][pscore6] would be nice. This process does require administrative privaleges, currently, as it install this globally.

To get PowerShell 6, run the following commands from PowerShell:

```
Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/PowerShell-6.2.2-win-x64.msi -OutFile PowerShell-6.2.2-win-x64.msi
msiexec /package PowerShell-6.2.2-win-x64.msi /qB ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1
```

Click on the dialogue box that pops up, asking for permission to perform the installation. All of the options for the installation should be set on the command line, and so no dialogue boxes should pop up, and once the installatino is finished, any windows should close automatically.

Once done, close the current PowerShell window, and open a new one by running `pwsh` to continue.

If any part of this process did not work, replace any use of `pwsh` with `powershell`.

## [scoop][]

We will use [scoop][] for package management.

In order to install [scoop][], we need to set the execution policy in PowerShell. I don't know about the [security implications of this][ps-execpolicy].

In PowerShell:

```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

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

## Configuring [GnuPG][]

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

Then we need to [configure `gpg-agent`][configure-gpg-agent] [with PuTTY support][gpg-putty], then [restart `gpg-agent`][restart-gpg-agent].

Instead of regular SSH support, I chose [PuTTY][] support as the tooling for connecting the [OpenSSh built into Windows][win32-openssh] to gnupg [is currently one of the only avenues to get the two to talk][openssh-gpg-connect], and it allows the use of PuTTY with the same authentication mechanism.

To enable putty support in gpg-agent, either edit the file indicated by the following command (this file might not exist and may need to be created):

```
(gpgconf --list-dirs socketdir) + "\gpg-agen.conf"
```

And put the string `enable-putty-support` on a single line in the file, or run the following command:

`echo "enable-putty-support:0:1" | gpgconf --change-options gpg-agent`

Either way, putty support is permanently enabled.

Now that putty support is enabled, reload `gpg-agent`:

```
gpg-connect-agent reloadagent /bye
```

## Bridge GnuPG and Win32-OpenSSH

Now, `wsl-ssh-pageant` is needed to bridge `ssh` and `gpg-agent`.

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

Before starting `wsl-ssh-pageant`, it's important to note that the command below run `wsl-ssh-pageant` in its own background process, which needs to be running each time `git` or `ssh` need to talke with `gpg-agent`. A step for setting this command to run on logon is pending.

The good news is that this process is detached from PowerShell, and closing PowerShell will not close this process, or prevent `wsl-ssh-pageant` from working with other PowerShell or console sessions.

Also, having `wsl-ssh-pageant` running does not appear to impede the use of both PuTTY and Windows' native ssh client from both using the keys stored on the key/card.

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

## Testing and finale

Now ssh should be able to see the keys on the key/card:

`ssh-add -L`

This is the most important part, and if this shows an error message about connecting to an agent, a bad response from an agent, or just nothing, then please make prolific use of your search engine of choice.

To download the repository, git should be able to talk with GitHub. To test this, [the following should print out a short message][github-test-ssh]:

```
ssh -T git@github.com
```

To then get `git` to be able to use the `ssh` client configured for interacting with `gpg-agent`, [set the `GIT_SSH` environment variable][git-ssh]:

```
Set-Item -Path Env:GIT_SSH -Value (scoop which ssh)
[Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $env:GIT_SSH, 'User')
```

To get git to use the correct `gpg` program, [set that in the global git config][git-gpg]:

```
git config --global gpg.program (scoop which gpg)
```

# Return to regular install

Now that all that's done, we can [continue with the installation.](./README.md#setup)



[git]: <https://git-scm.com/>
[gnupg]: <https://www.gnupg.org/>
[OpenSSH]: <https://www.openssh.com/>
[af-unix]: <http://man7.org/linux/man-pages/man7/unix.7.html>
[powershell]: <https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-5.1>
[scoop]: <https://github.com/lukesampson/scoop>
[pscore6]: <https://aka.ms/pscore6>
[ps-execpolicy]: <https://docs.microsoft.com/en-us/PowerShell/module/microsoft.PowerShell.core/about/about_execution_policies?view=PowerShell-6>
[configure-gpg-agent]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Configuration.html>
[restart-gpg-agent]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Protocol.html#Agent-Protocol>
[gpg-putty]: <https://www.gnupg.org/documentation/manuals/gnupg/Agent-Options.html#option-_002d_002denable_002dssh_002dsupport>
[PuTTY]: <https://www.chiark.greenend.org.uk/~sgtatham/putty/>
[win32-openssh]: <https://github.com/PowerShell/openssh-portable>
[openssh-gpg-connect]: <https://github.com/PowerShell/Win32-OpenSSH/issues/827>
[default-win-pipe]: <https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297>
[named-pipe]: <https://docs.microsoft.com/en-us/windows/win32/ipc/named-pipes>
[github-test-ssh]: <https://help.github.com/en/articles/testing-your-ssh-connection>
[git-ssh]: <https://git-scm.com/book/en/v2/Git-Internals-Environment-Variables#_miscellaneous>
[git-gpg]: <https://stackoverflow.com/a/43393650>