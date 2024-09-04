use std [log]

export const plugin_dir = '/usr/lib/keepass2/Plugins'

export def main [--force-update] {
    ^sudo mkdir -p $plugin_dir

    # copy and enable:
    # - services that download the plugins, overwriting the current plugin files, but only when keepass isn't running
    # - timers to run those services

    # ideally, the services won't download the plugins unless a new version is available, and will keep track of the current versions in a `versions.nuon` file

    let absBootstrapDir = (chezmoi dump-config --format=json | from json | get data.absBootstrapDir)
    let temp_keetraytotp_plgx = ($absBootstrapDir | path join 'KeeTrayTOTP.plgx')
    let temp_readable_passphrase_plgx = ($absBootstrapDir | path join 'ReadablePassphrase.plgx')
    let keetraytotp_plgx = ($plugin_dir | path join 'KeeTrayTOTP.plgx')
    let readable_passphrase_plgx = ($plugin_dir | path join 'ReadablePassphrase.plgx')

    if $force_update or not ($temp_keetraytotp_plgx | path exists) {
        keetraytotp --to $temp_keetraytotp_plgx
    }
    if $force_update or not ($temp_readable_passphrase_plgx | path exists) {
        readable-passphrase --to $temp_readable_passphrase_plgx
    }

    if not ($keetraytotp_plgx | path exists) {
        ^sudo cp $temp_keetraytotp_plgx $keetraytotp_plgx
    }
    if not ($readable_passphrase_plgx | path exists) {
        ^sudo cp $temp_readable_passphrase_plgx $readable_passphrase_plgx
    }
}

export def keetraytotp [--to: path] {
    let url = (
        http get 'https://api.github.com/repos/KeeTrayTOTP/KeeTrayTOTP/releases/latest' |
        get assets |
        where name == 'KeeTrayTOTP.plgx' |
        get browser_download_url
    )
    http get $url |
    save -f $to
}

export def "readable-passphrase" [--to: path] {
    let release = (http get 'https://api.github.com/repos/ligos/readablepassphrasegenerator/releases/latest')
    let version = (
        $release |
        get tag_name |
        str substring ('release-' | split chars | length)..
    )
    let url = (
        get assets |
        where name == $'ReadablePassphrase.($version).plgx' |
        get browser_download_url
    )
    http get $url |
    save -f $to
}
