use utils.nu [powershell-safe]
use std [log]

const platform = ($nu.os-info.name)

# Based on:
# https://github.com/mawillcockson/dotfiles/blob/798d6ea7267a73502ae8242fae1aa4b0d0618af5/INSTALL_windows.md
# NOTE::DONE This could close the running ssh-agent, and the WSL-SSH-Pageant,
# before starting the latter again, as well as check for the existence of the
# appropriate environment variable, and the presence of the necessary programs
export def main [] {
    if ($env | get SSH_AUTH_SOCK? | is-empty) {
        # This is the default name of the named pipe used Windows' builtin ssh,
        # set explicitly here. More info:
        # https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297
        log debug 'setting SSH_AUTH_SOCK environment variable for gpg and ssh'
        match $platform {
            'windows' => {
                powershell-safe -c `[Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', "\\.\pipe\openssh-ssh-agent", 'User')`
            },
            _ => {return (error make {'msg': $'not implemented for platform: ($platform)'})},
        }
    }
    ^gpgconf --kill all
    let wsl_ssh_pageant_pids = (
        ps
        | str contains --ignore-case 'wsl-ssh-pageant.exe' name
        | where name == true
        | get pid
    )
    if ($wsl_ssh_pageant_pids | is-not-empty) {
        kill ($wsl_ssh_pageant_pids | first) ...($wsl_ssh_pageant_pids | skip 1)
    }
    try {
        rm -r (^gpgconf --list-dirs agent-ssh-socket)
    }
    ^gpg-connect-agent updatestartuptty /bye
    match $platform {
        'windows' => {
            powershell-safe -c `& {start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-systray','-winssh','openssh-ssh-agent','-wsl',(gpgconf --list-dirs agent-ssh-socket),'-force') -WindowStyle hidden }`
        },
        _ => {return (error make {'msg': $'not implemented for platform: ($platform)'})},
    }
    sleep 3sec
    ^ssh-add -l
}
