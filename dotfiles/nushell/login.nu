if (which 'tmux' | is-not-empty) {
    try { ^tmux set-option -qog default-shell $nu.current-exe | ignore }
    if ('TMUX' not-in $env) and ((^tmux has-session | complete | get exit_code) == 0) {
        if (^tmux has-session -t ssh | complete | get exit_code) == 0 {
            if ('SSH_AUTH_SOCK' in $env) {
                ^tmux set-environment -t ssh SSH_AUTH_SOCK $env.SSH_AUTH_SOCK
            }
            if (^tmux list-windows -t ssh | lines | length) == 1 {
                ^tmux new-window -t ssh
            }
            commandline edit --replace 'tmux attach -t ssh'
        } else {
            commandline edit --replace 'tmux attach -d'
        }
    }
    commandline edit --replace 'try { tmux attach -d } catch { tmux -f ~/.tmux.conf }'
}
