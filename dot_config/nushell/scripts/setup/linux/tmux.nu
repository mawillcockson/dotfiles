use std/log

# return the path to my dotfiles
export def "get dotfiles-dir" [] {
    ^chezmoi dump-config --format=json |
    from json |
    get 'workingTree' |
    path expand --strict
}

export def "get-config-locations" [] {
    return {
        system: '/etc/tmux.conf',
        user: ('~/.tmux.conf' | path expand),
    }
}

export def main [] {
    let conf = (get dotfiles-dir | path join 'tmux' '.tmux.conf')
    let config_path = (get-config-locations)

    log info 'copy configuration into place'
    if ($config_path.system | path exists) {
        log warning $'system config already exists at ($config_path.system); using user path ($config_path.user) instead'
        cp --verbose --no-clobber $conf $config_path.user
        return true
    }
    ^sudo cp --verbose --no-clobber $conf $config_path.system
    if ($config_path.user | path exists) {
        log warning $'user configuration at ($config_path.user) will override system configuration; recommend removing it'
    }
    log info "it's recommended to also install xclip (the configuration doesn't yet use wl-clipboard)"
}
