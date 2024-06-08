if (-not (Test-Path Env:XDG_CONFIG_HOME)) {
	write-host "Need XDG_CONFIG_HOME set to setup starship"
} else {
	if (
		("$Env:COMPUTERNAME" -ne "INSPIRON15-3521") `
		-and (-not (Test-Path Env:NO_STARSHIP)) `
		-and (gcm starship -ErrorAction SilentlyContinue) `
	) {
		$Env:STARSHIP_CACHE = "$Env:XDG_CONFIG_HOME\starship"
		$Env:STARSHIP_CONFIG = "$Env:STARSHIP_CACHE\starship.toml"
		# $Env:STARSHIP_LOG = "trace"
		Invoke-Expression (&starship init powershell)
	}
}

if (gcm fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd --version-file-strategy=recursive --shell=power-shell | Out-String | iex
}

# https://docs.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption
if (-not (Test-Path Env:OneDrive)) {
    write-host "OneDrive not signed in? Not setting PowerShell command history to OneDrive"
} else {
    Set-PSReadLineOption `
        -HistorySavePath "$Env:OneDrive\Documents\WindowsPowerShell\ConsoleHost_history.txt" `
        -HistorySaveStyle SaveIncrementally
}

function Start-SshFallback {
    if (-not (Test-Path Env:SSH_AUTH_SOCK)) {
        write-host "has scoop_install.ps1 been run, to make sure everything is installed?"
    } else {
        del -Path (gpgconf --list-dirs agent-ssh-socket) -Force -ErrorAction SilentlyContinue
        gpg-connect-agent.exe updatestartuptty /bye
        powershell -Command "& {start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-systray','-winssh','openssh-ssh-agent','-wsl',(gpgconf --list-dirs agent-ssh-socket),'-force') -WindowStyle hidden }"
        Start-Sleep -Seconds 3
        ssh-add -l
    }
}

function Start-Ssh {
    nu -c "use start-ssh.nu ; start-ssh"
}

function dt {
    $date = Get-Date -UFormat "%Y-%m-%dT%H%M%Z00"
    Set-Clipboard -Value $date
    write-host $date
}

function Setup-GitLocal {
    git config --local user.name "Matthew W"
    git config --local user.email "matthew@willcockson.family"
    git config --local user.signingKey "EDCA9AF7D273FA643F1CE76EA5A7E106D69D1115"
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
