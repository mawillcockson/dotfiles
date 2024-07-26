use std [log]
use consts.nu [platform]
use utils.nu ["powershell-safe"]

export def "find-kanata" [] {
    cd $env.EGET_BIN
    glob --no-dir --no-symlink --depth 1 'kanata*' |
    first
}

export def main [--cfg: path = ""] {
    let cfg = if ($cfg | is-not-empty) {$cfg} else {
        $env.XDG_CONFIG_HOME |
        path join 'kanata' 'config.kbd'
    }
    run-external (find-kanata) '--cfg' $cfg
}
