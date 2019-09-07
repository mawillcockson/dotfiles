# The Windows hurdle

By far the most difficult setup has been Windows, and forcing the use of command-line Unix tools.

It would probably be easier to use GUI tools built for windows, as opposed to lifting the entire setup from other operating systems, and transplanting it to Windows.

# Getting the repository

In order to get the repository we need git and gnupg.

Windows now comes with OpenSSH, but it listens on a named pipe, not a Unix domain socket, which is what gnupg uses, so we need a program to shuttle between the two.

We also need a program to help automate downloading and managing all these programs.

Unless noted, all commands are run in order, in one [PowerShell][] session.

## [PowerShell Core 6 (Optional)][pscore6]

It would be nice to grab [PowerShell Core 6][pscore6], though this is optional.

From PowerShell:

```
Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/PowerShell-6.2.2-win-x64.msi -OutFile PowerShell PowerShell-6.2.2-win-x64.msi
msiexec /package PowerShell-6.2.2-win-x64.msi /qB ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1
```

Click through the dialogue boxes that pop up.

Once done, close the current PowerShell window, and open a new one by running `pwsh` to continue.

## [scoop][]

We will use [scoop][] for package management.

In order to install [scoop][], we need to set the execution policy in PowerShell. I don't know about the [security implications of this][ps-execpolicy].

In PowerShell:

```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb get.scoop.sh | iex
```

Then we'll install the programs scoop needs, as well as the ones we need.

```
scoop install aria2 git
scoop bucket add extras
scoop install gnupg wsl-ssh-pageant
```

## Configuring GnuPG

Now we insert the OpenPGP-compatible card or security key, and gnupg should see it:

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

Then we need to [restart the gpg-agent][restart-gpg-agent] [with PuTTY support][gpg-putty].

Instead of regular SSH support, I chose [PuTTY][] support as the tooling for connecting the [OpenSSh built into Windows][win32-openssh] to gnupg [is currently one of the only avenues to get the two to talk][openssh-gpg-connect], and it allows the use of PuTTY with the same authentication mechanism.

To enable putty support in gpg-agent, either edit the file indicated by the following command:

```
[System.Web.HttpUtility]::UrlDecode((gpgconf --list-components | Select-String -Pattern gpg-agent | %{ $a=$_.Line.Split(':')[2]; $a}))
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
$env:SSH_SUTH_SOCK = "\\.\pipe\ssh-pageant"
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

Before starting `wsl-ssh-pageant`, it's important to note that the command below causes a window to pop up. This window is running `wsl-ssh-pageant`, and closing it stops the process.

The good news is that this window is detached form PowerShell, and closing PowerShell will not close this window, or prevent `wsl-ssh-pageant` from working with other PowerShell or console sessions.

Also, having `wsl-ssh-pageant` running does not appear to impede the use of both PuTTY and Windows' native ssh client from both using the keys stored on the key/card.

So to start `wsl-ssh-pageant`, run:

```
start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-winssh','ssh-pageant','-wsl',(gpgconf --list-dirs agent-ssh-socket))
```

Feel free to minimize the window that pops up, making sure not to close it. If it is closed, rerun the command.

If the window pops up briefly, before closing by itself, something is wrong. The error can be viewed by running the command in the current console, as opposed to spawning a new one:

```
wsl-ssh-pageant.exe -systray -winssh "\\.\pipe\ssh-pageant" -wsl (gpgconf --list-dirs agent-ssh-socket)
```

## Testing and finale

Now ssh should be able to see the keys on the key/card:

`ssh-add -L`

This is the most important part, and if this shows an error message about connecting to an agent, a bad response from an agent, or just nothing, then please make prolific use of your search engine of choice.



[powershell]: <https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-5.1>
[scoop]: <https://github.com/lukesampson/scoop>
[pscore6]: <https://aka.ms/pscore6>
[ps-execpolicy]: <https://docs.microsoft.com/en-us/PowerShell/module/microsoft.PowerShell.core/about/about_execution_policies?view=PowerShell-6>
[restart-gpg-agent]: 
[gpg-putty]: 
[PuTTY]: <https://www.chiark.greenend.org.uk/~sgtatham/putty/>
[win32-openssh]: <https://github.com/PowerShell/openssh-portable>
[openssh-gpg-connect]: <https://github.com/PowerShell/Win32-OpenSSH/issues/827>
[default-win-pipe]: <https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297>
[named-pipe]: <https://docs.microsoft.com/en-us/windows/win32/ipc/named-pipes>