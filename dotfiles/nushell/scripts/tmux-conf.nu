def exit0 [] {
    complete | get exit_code | ($in == 0)
}

export def main [] {
    if (which 'tmux' | is-empty) {
        return (error make {
            'msg': 'tmux not installed; try `nu -c "use package; package install tmux"`'
        })
    }

    try { ^tmux set-option -qog default-shell $nu.current-exe | ignore }
    if ('TMUX' not-in $env) and (^tmux has-session | exit0) {
        if (^tmux has-session -t ssh | exit0) {
            if ('SSH_AUTH_SOCK' in $env) {
                ^tmux set-environment -t ssh SSH_AUTH_SOCK $env.SSH_AUTH_SOCK
            }
            if (^tmux list-windows -t ssh | lines | length) == 1 {
                ^tmux new-window -t ssh
            }
        }
    }
}
