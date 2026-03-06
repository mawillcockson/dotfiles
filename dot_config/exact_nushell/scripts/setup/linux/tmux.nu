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

export def main [
    # whether to overwrite the configuration or not
    --overwrite,
]: nothing -> nothing {
    let conf = (get dotfiles-dir | path join 'dot_config' 'tmux' '.tmux.conf')
    let config_path = (get-config-locations)
    let user_config_exists = ($config_path.user | path exists)
    let system_config_exists = ($config_path.system | path exists)

    log info 'copy configuration into place'
    if ($overwrite) {
        if not ($user_config_exists) {
            log info $'user config not present at ($config_path.user | to nuon)
creating/overwriting system config at ($config_path.system | to nuon)'
            sudo cp --verbose $conf $config_path.system
            return null
        }
        log info $'user configuration exists at ($config_path.user | to nuon); overwriting it'
        cp --verbose $conf $config_path.user
        log info $'placing system config at ($config_path.system | to nuon)'
        sudo cp --verbose $conf $config_path.system
        return null
    }

    if ($system_config_exists) {
        log warning $'system config already exists at ($config_path.system)
copying configuration to user path ($config_path.user | to nuon) instead

to overwrite/clobber configs, do:
nu -c "use setup; setup linux tmux --overwrite"'
        cp --verbose --no-clobber $conf $config_path.user
        return null
    }
    sudo cp --verbose --no-clobber $conf $config_path.system
    if ($user_config_exists) {
        log warning $'user configuration at ($config_path.user | to nuon) will override system configuration at ($config_path.system | to nuon); recommend removing it'
    }
    log info "it's recommended to also install xclip (the configuration doesn't yet use wl-clipboard)"
}
