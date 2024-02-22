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

# https://docs.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption
if (-not (Test-Path Env:OneDrive)) {
    write-host "OneDrive not signed in? Not setting PowerShell command history to OneDrive"
} else {
    Set-PSReadLineOption `
        -HistorySavePath "$Env:OneDrive\Documents\WindowsPowerShell\ConsoleHost_history.txt" `
        -HistorySaveStyle SaveIncrementally
}

function Start-Ssh {
    if (-not (Test-Path Env:SSH_AUTH_SOCK)) {
        write-host "has scoop_install.ps1 been run, to make sure everything is installed?"
    } else {
        gpg-connect-agent.exe updatestartuptty /bye
        powershell -Command "& {start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-systray','-winssh','openssh-ssh-agent','-wsl',(gpgconf --list-dirs agent-ssh-socket),'-force') -WindowStyle hidden }"
        Start-Sleep -Seconds 3
        ssh-add -L
    }
}
