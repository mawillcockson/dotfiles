if (which 'tmux' | is-not-empty) {
    use tmux-conf.nu
    tmux-conf
}
