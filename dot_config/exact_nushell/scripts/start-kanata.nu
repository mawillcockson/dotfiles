use std/log

export def "find-kanata" [] {
    cd $env.EGET_BIN
    glob --no-dir --no-symlink --depth 1 'kanata*' |
    first
}

export def main [--cfg: path = ""] {
    if (ps | where name =~ 'kanata' | is-not-empty) {
        log info "kanata already running"
        return
    }

    let cfg = if ($cfg | is-not-empty) {$cfg} else {
        $env.XDG_CONFIG_HOME |
        path join 'kanata' 'kanata.kbd'
    }
    run-external (find-kanata) '--cfg' $cfg
}
