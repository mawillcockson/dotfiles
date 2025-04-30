export def main []: nothing -> nothing {
    {
        'global': {
            'target': ($env.EGET_BIN),
            'upgrade_only': true,
        },
    } |
    insert 'FiloSottile/age' {'asset_filters': ['^.proof']} |
    insert 'asdf-vm/asdf' {'asset_filters': ['^.md5']} |
    match $nu.os-info.name {
        'windows' => {
            insert 'nalgeon/sqlite' {'asset_filters': ['sqlean.exe']} |
            insert 'getsops/sops' {'asset_filters': ['.exe', '^.json']} |
            insert 'twpayne/chezmoi' {'asset_filters': ['.zip']} |
            insert 'jtroo/kanata' {'asset_filters': ['winIOv2.exe']} |
            insert 'elm/compiler' {'asset_filters': ['.gz', 'windows']} |
            insert 'cargo-bins/cargo-binstall' {'asset_filters': ['msvc.zip', '^.sig']}
        },
        'linux' => {
            insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-ubuntu']} |
            insert 'jtroo/kanata' {'asset_filters': ['kanata', '^.']} |
            insert 'neovide/neovide' {'asset_filters': ['.AppImage', '^.zsync']} |
            insert 'sharkdp/fd' {'asset_filters': ['gnu']} |
            insert 'JohnnyMorganz/StyLua' {'asset_filters': ['linux', 'musl']} |
            insert 'rclone/rclone' {'asset_filters': ['.zip']} |
            insert 'nushell/nushell' {'asset_filters': ['gnu'], 'file': 'nu'} |
            insert 'ClementTsang/bottom' {'asset_filters': ['gnu', '^gnu-2-17']} |
            insert 'duckdb/duckdb' {'asset_filters': ['duckdb_cli', '.gz']}
        },
        'macos' => {
            insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-macos']}
        },
        _ => {
            insert 'nalgeon/sqlite' {'download_source': true}
        },
    } |
    to toml |
    prepend [
        $'# this file is auto-generated in ($env | get CURRENT_FILE? | default 'eget_setup.nu')',
        '',
    ] |
    str join "\n" |
    save -f $env.EGET_CONFIG |
    null
}
