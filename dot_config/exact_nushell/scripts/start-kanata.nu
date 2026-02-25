use std/log
use consts.nu [platform]

# return the location at which the config is expected to be found
export def "expected config location" [
    # return the location in which kanata will first search for a config
    --initial,
]: [nothing -> path] {
    if $initial {
        match $platform {
# kanata (as of 2026-02-25) uses dirs::config_dir():
# https://github.com/jtroo/kanata/blob/cd2be50a467e7bb6ba128166d3b3c9924bbcfb06/src/lib.rs#L38-L39
# https://github.com/jtroo/kanata/blob/cd2be50a467e7bb6ba128166d3b3c9924bbcfb06/Cargo.toml#L44
# which uses the Windows "Known Folders" API:
# https://codeberg.org/dirs/dirs-rs/src/commit/1c2e3efad531aa67a5656eaedf53fdb8fa9094f7/README.md?display=source#L18

# on Linux, it uses the XDG base directory specification:
# https://codeberg.org/dirs/dirs-rs/src/commit/1c2e3efad531aa67a5656eaedf53fdb8fa9094f7/README.md?display=source#L16
            'windows' => {
                return (do {
                    # from:
                    # https://gist.github.com/josy1024/5cca8a66bfdefb12abff1721ff44f35f?permalink_comment_id=3035066#gistcomment-3035066
                    # https://stackoverflow.com/a/16658189
                    use utils.nu ["powershell-safe"]
                    powershell-safe -c '[Environment]::GetFolderPath("ApplicationData") | ConvertTo-Json -Compress' |
                    get stdout |
                    from json |
                    path join 'kanata' 'kanata.kbd'
                })
            },
            'linux' => {
                return (
                    if ($env has 'XDG_CONFIG_HOME') {
                        log debug $'using $XDG_CONFIG_HOME: ($env.XDG_CONFIG_HOME)'
                        echo $env.XDG_CONFIG_HOME
                    } else if (which chezmoi | is-not-empty) {
                        let XDG_CONFIG_HOME = (
                            chezmoi dump-config --format=json | from json | get env.XDG_CONFIG_HOME
                        )
                        log debug $'using XDG_CONFIG_HOME from chezmoi: ($XDG_CONFIG_HOME)'
                        $XDG_CONFIG_HOME
                    } else {
                        let XDG_CONFIG_HOME = (echo '~/.config' | path expand)
                        log debug $'using XDG base directory default: ($XDG_CONFIG_HOME)'
                    } | path join 'kanata' 'kanata.kbd'
                )
            },
            _ => {
                return (error make {msg: $"I don't use this platform: ($platform)"})
            },
        }
    }

    return (
    # NOTE::PERFORMANCE I'm doing it this way, instead of using `default`,
    # since `default` computes its value, even if it's never returned, and
    # running chezmoi is a bit expensive
        if ($env has 'XDG_CONFIG_HOME') {
            $env.XDG_CONFIG_HOME?
        } else if (which chezmoi | is-not-empty) {
            chezmoi dump-config --format=json |
            from json |
            get env.XDG_CONFIG_HOME
        } else {
            default ('~/.config' | path expand)
        } | path join 'kanata' 'kanata.kbd'
    )
}

export def "find-config" []: [nothing -> path] {
    let config_file = (expected config location)
    if not ($config_file | path exists) {
        let msg = $'could not find config in the expected location: ($config_file | to nuon)'
        log error $msg
        return (error make {msg: $msg})
    }
    return $config_file
}

export def "find-exe" [] {
    $env.HOME = (
        $env |
        get HOME? USERPROFILE? |
        append [(
            if (which chezmoi | is-not-empty) {
                chezmoi dump-config --format=json |
                from json |
                get destDir
            } else {null}
        )] |
        append ($nu | get home-dir? home-path?) |
        compact --empty |
        first
    )
    $env.EGET_BIN = $env.EGET_BIN? | default (
        $env.HOME | path join 'apps' 'eget-bin'
    )
    let kanatas = (
        with-env {PATH: (
            $env.PATH |
            prepend $env.EGET_BIN |
            uniq |
            where {path exists} |
            path expand --strict
        )} {which | where type == 'external' and command starts-with 'kanata'} |
        get path
    )
    if ($kanatas | is-empty) {
        let msg = 'cannot find an executable starting with "kanata"'
        log error $msg
        return (error make {msg: $msg})
    }
    return ($kanatas | first)
}

export def "is-running" []: [nothing -> bool] {
    return (ps | where name =~ 'kanata' | is-not-empty)
}

export def main [--cfg: path = ""]: [nothing -> nothing] {
    if (is-running) {
        log info 'kanata is already running'
        return null
    }

    let cfg_path = $cfg | default --empty (
        $env.XDG_CONFIG_HOME |
        path join 'kanata' 'kanata.kbd'
    )
    do {
        cd ($cfg_path | path dirname)
        run-external (find-exe) '--cfg' $cfg
    }
}
