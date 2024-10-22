use std/log

export const keepass_plugin_dir = '/usr/lib/keepass2/Plugins'
export const shell_includes_dir = '/usr/local/share/sh'
# I should install the script in /usr/local/bin
# https://askubuntu.com/a/308048
export const custom_scripts_dir = '/usr/local/bin'
# This is the place indicated in the documentation for "System units created by the administrator":
# https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#id-1.8.4
export const custom_systemd_units_dir = '/etc/systemd/system'

export def "get-sourcedir" [] {
    chezmoi dump-config --format=json | from json | get sourceDir
}

export def main [] {
    ^sudo mkdir -p $keepass_plugin_dir $shell_includes_dir $custom_scripts_dir

    let sourceDir = get-sourcedir
    let script = ($sourceDir | path join 'debian' 'usr' 'local' 'bin' 'update_keepass_plugins.sh')
    ^sudo cp $script $custom_scripts_dir
    # not strictly necessary, but nice
    ^sudo chmod a+x ($custom_scripts_dir | path join 'update_keepass_plugins.sh')
    let auxiliaries = do {
        cd ($sourceDir | path join 'debian' 'usr' 'local' 'share' 'sh')
        glob '*.sh'
    }
    ^sudo cp ...($auxiliaries) $shell_includes_dir
    let systemd_units = do {
        cd ($sourceDir | path join 'debian' 'etc' 'systemd' 'system')
        glob 'update_keepass_plugins.*'
    }
    ^sudo cp ...($systemd_units) $custom_systemd_units_dir
    ^sudo systemctl daemon-reload
    ^sudo systemctl enable ($custom_systemd_units_dir | path join 'update_keepass_plugins.timer')
}
