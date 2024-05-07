use utils.nu [powershell-safe]
use std [log]

const platform = ($nu.os-info.name)

# Based on:
# https://github.com/mawillcockson/dotfiles/blob/798d6ea7267a73502ae8242fae1aa4b0d0618af5/INSTALL_windows.md
# NOTE::DONE This could close the running ssh-agent, and the WSL-SSH-Pageant,
# before starting the latter again, as well as check for the existence of the
# appropriate environment variable, and the presence of the necessary programs
export def main [] {
    log debug 'setting environment variables for gpg and ssh'
    match $platform {
        'windows' => {
            # This is the default name of the named pipe used Windows' builtin ssh,
            # set explicitly here. More info:
            # https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297
            let named_pipe = (
                $env
                | get SSH_AUTH_SOCK?
                | default '\\.\pipe\openssh-ssh-agent'
            )
            if ($env.SSH_AUTH_SOCK? | is-empty) {
                log info $'setting permanent user environment variable SSH_AUTH_SOCK -> ($named_pipe | to nuon)'
                powershell-safe -c $"[Environment]::SetEnvironmentVariable\('SSH_AUTH_SOCK', "($named_pipe)", 'User'\)"
            }
            {'SSH_AUTH_SOCK': ($named_pipe)}
        },
        'linux' => {
            {'GPG_TTY': (^tty)}
            return (error make {'msg': 'linux platform has not been fully implemented'})
        },
        _ => {return (error make {'msg': $'not implemented for platform: ($platform)'})},
    } | load-env
    log debug 'killing all gpg services'
    ^gpgconf --kill all
    let wsl_ssh_pageant_pids = (
        ps
        | str contains --ignore-case 'wsl-ssh-pageant.exe' name
        | where name == true
        | get pid
    )
    if ($wsl_ssh_pageant_pids | is-not-empty) {
        log debug $'killing wsl-ssh-pageant -> ($wsl_ssh_pageant_pids | to nuon)'
        kill ($wsl_ssh_pageant_pids | first) ...($wsl_ssh_pageant_pids | skip 1)
    }
    let agent_ssh_socket = (^gpgconf --list-dirs agent-ssh-socket)
    if ($agent_ssh_socket | path exists) {
        log debug $'trying to remove agent ssh socket -> ($agent_ssh_socket | to nuon)'
        match $platform {
            'windows' => {
                # NOTE::BUG the builtin `rm` says "directory not found"
                powershell-safe -c 'Remove-Item -Path (gpgconf --list-dirs agent-ssh-socket) -Force -ErrorAction SilentlyContinue'
            },
            _ => {
                rm --force $agent_ssh_socket
            },
        }
    }
    if ($agent_ssh_socket | path exists) {
        log warning $'was not able to remove file -> ($agent_ssh_socket | to nuon)'
    }
    log debug 'reloading gpg-agent'
    try {^gpg-connect-agent updatestartuptty /bye}
    match $platform {
        'windows' => {
            log debug 'starting background wsl-ssh-pageant'
            powershell-safe -c `& {start-process -filepath wsl-ssh-pageant.exe -ArgumentList ('-systray','-winssh','openssh-ssh-agent','-wsl',(gpgconf --list-dirs agent-ssh-socket),'-force') -WindowStyle hidden }`
        },
        _ => {return (error make {'msg': $'not implemented for platform: ($platform)'})},
    }
    sleep 3sec
    log debug 'can ssh-add interact with the running gpg agent providing ssh support?'
    ^ssh-add -l
}
