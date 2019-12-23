# Overview

The goal of this process will be to get [Python][] installed, so that the rest of the install can be automated.

If you already have [Python][], you can skip to [the setup.][./README.md#setup] However, some of the tools I use rely on having [PowerShell][] set up the way this guide sets it up.

# Getting the repository

In order to get and use the repository we need [`git`][git], [`gpg`][gnupg], and [`python`][python].

All three of these can be downloaded and installed using [scoop][], which we will download and install in a following section.

We also need a program to help automate downloading and installing all these programs. We'll use [Windows PowerShell][PowerShell] for this.

This document should describe the necessary steps to reproduce the environment I use, and each step is accompanied by a PowerShell snippet that _should_ perform the listed actions. These snippets are intended to be run one at a time, one after another, all in one session. Some of them ask for the sessions to be closed and restarted, and others set variables that are used in subsequent steps, and if the window is closed and reopened accidentally, some steps may not work.

If something this guide relies on has changed, the instructions should still describe the appropriate actions that can be performed, and this guide can be used with very minimal interaction with PowerShell. Unfortunately, the accompanying PowerShell snippets may not work. If this happens, feel free to [open an issue on this project][project-issue] by [following the instructions from GitHub][github-issues-howto], which does require creating a free [GitHub account][github-account].

## [PowerShell Core][pscore6]

While not strictly necessary, having the latest and greatest [PowerShell Core][pscore6] makes the rest of these steps easier. Currently, the PowerShell snippet for this step requires administrative privaleges, as it installs PowerShell for all users.

To get PowerShell Core, we'll follow [Microsoft's instructions,][pscore-install] which generically ask to visit the [GitHub releases page for PowerShell Core,][pscore-releases] and download an install the package for the latest stable release for your platform.

If we want to do this from PowerShell, [and are on versions of Windows earlier than Windows 10][tls-pre10], depending on the version, we need to take some extra steps first [to enable the TLS protocol by modifying the Windows Registry][enable-tls-registry]:

```powershell
md "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2"
md "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
md "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client"
 
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "Enabled" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -name "DisabledByDefault" -value 0 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "Enabled" -value 1 -PropertyType "DWord"
new-itemproperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -name "DisabledByDefault" -value 0 -PropertyType "DWord"

reg add HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319 /v SystemDefaultTlsVersions /t REG_DWORD /d 1 /f /reg:64
```

To do this from an existing PowerShell, we need to do some extra steps first to enable the use of `https` to download the file from GitHub [if we are on versions of Windows earlier than Windows 10][tls-pre10], [using PowerShell][pwsh-tls]. Fortunately, PowerShell Core includes this functionality, so once it is installed, everything else should work, regardless of the age of the system.

To do all this, [open a PowerShell session][open-pwsh] and run the following commands:

```powershell
((iwr -useb https://api.github.com/repos/PowerShell/PowerShell/releases/latest).Content -split "," | Select-String -Pattern "https.*x64.msi" | Select-Object -first 1).Line -match "https.*msi" | %{ iwr -useb $Matches[0] -outf $Env:TEMP\pwsh_x64.msi }
start-process -filepath cmd.exe -argumentlist ('/c', 'echo Installing PowerShell Core... && echo Waiting for PowerShell to close && timeout /t 3 /nobreak && msiexec /package %TEMP%\pwsh_x64.msi /qB ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1 && pwsh -Command "rm $Env:TEMP\pwsh_x64.msi; start-process -filepath pwsh" && exit'); exit
```

Click on the dialogue box that pops up, asking for permission to perform the installation. All of the options for the installation should have been set by the command, and so no dialogue boxes should pop up, and once the installation is finished, any windows should close automatically.

Once done, the new version of powershell should be available by running the command `pwsh`, however the installation process did not update the current session with information on where to find the new program, [so we'll do that now][pwsh-reload]:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

Then we can run:

```powershell
pwsh
```

If any part of this process did not work, or produced errors, or if the account does not have administrative privaledges, replace any use of `pwsh` with `powershell` in all further sections.

## [scoop][]

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

## Testing [GnuPG][]

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

## Configuring [GnuPG][]

Now that we know that `gpg` can see the key/card, we can [configure `gpg-agent`][configure-gpg-agent] [with PuTTY support][gpg-putty], then [restart `gpg-agent`][restart-gpg-agent], as described in this section.

Instead of regular SSH support, I chose [PuTTY][] support as the tooling for connecting the [OpenSSH suite built into Windows 10][win32-openssh] to gnupg [is currently one of the only avenues to get the two to talk][openssh-gpg-connect], and it allows the use of PuTTY with the same authentication mechanism.

One thing to note as a result of this setup is that, since [OpenSSH has been shipped with Windows 10 since autumn 2018][windows-ssh-info], this setup won't work exactly as expected on any version prior to this, or versions lacking this OpenSSH suite.

To enable putty support in `gpg-agent`, either edit the file indicated by the following command (this file might not exist and may need to be created):

```
(gpgconf --list-dirs socketdir) + "\gpg-agent.conf"
```

And put the string `enable-putty-support` on a single line in the file, or run the following command:

```powershell
echo "enable-putty-support:0:1" | gpgconf --change-options gpg-agent
```

Either way, putty support is permanently enabled.

Now that putty support is enabled, reload `gpg-agent`:

```
gpg-connect-agent reloadagent /bye
```

## Bridge GnuPG and Win32-OpenSSH

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

Then, we remove the socket file that `gpg-agent` creates so that `wsl-ssh-pageant` can create that file:

```powershell
Remove-Item -ErrorAction Ignore (gpgconf --list-dirs agent-ssh-socket)
```

Lastly, we also make sure git knows where to find the `ssh` and `gpg` programs by running the following commands:

```powershell
git config --global core.sshCommand ((gcm ssh).Path -replace "\\","\\")
# Tell git that the ssh program is OpenSSH: https://git-scm.com/docs/git-config#Documentation/git-config.txt-sshvariant
git config --global ssh.variant ssh
git config --global gpg.program ((gcm gpg).Path -replace "\\","\\")
```

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

## Testing and finale

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

# Return to regular install

Now that all that's done, we can [continue with the installation.](./README.md#setup)



[enable-tls-registry]: <https://palmarg.wordpress.com/2014/06/09/enabling-tls-1-2-using-powershell/>
[pwsh-tls]: <https://docs.microsoft.com/en-us/security/solving-tls1-problem#update-windows-powershell-scripts-or-related-registry-settings>
[tls-pre10]: <https://docs.microsoft.com/en-us/security/solving-tls1-problem#ensuring-support-for-tls-12-across-deployed-operating-systems>
[pscore-install]: <https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-6#installing-the-msi-package>
[open-pwsh]: <https://docs.microsoft.com/en-us/powershell/scripting/getting-started/starting-windows-powershell>
[project-issue]: <https://github.com/mawillcockson/dotfiles/issues/new>
[github-issues-howto]: <https://help.github.com/en/articles/creating-an-issue>
[github-account]: <https://github.com/join?return_to=https%3A%2F%2Fgithub.com%2Fmawillcockson%2Fdotfiles>
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
