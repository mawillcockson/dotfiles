use utils.nu ["path is-link", "ln -s"]

const platform = ($nu.os-info.name)

export def main [] {
    let configs = match $platform {
        'windows' => ($env | get OneDrive? ONEDRIVE? ONEDRIVECONSUMER? OneDriveConsumer? | compact --empty | first | path join 'Documents' 'configs'),
        'android' => ($env | get XDG_CONFIG_HOME? | default '/data/data/com.termux/files/home/.config'),
        _ => {
            return (error make {msg: 'not implemented for this platform'})
        },
    }
    let dotfiles = match $platform {
        'windows' => $env.USERPROFILE,
        'android' => '/sdcard/',
        _ => {
            return (error make {msg: 'not implemented for this platform'})
        },
    } | path join 'projects' 'dotfiles' 'dotfiles'
    let folders = ([
        'starship',
        'nvim',
        'xonsh',
        'atuin',
        'nushell',
    ] | append (match $platform {
            'windows' => ['powershell', 'scoop', 'clink'],
            'android' => ['termux'],
            _ => [],
        }
    ))

    $folders | each {|name|
        let in_configs = $configs | path join $name
        let in_dotfiles = $dotfiles | path join $name
        if ($in_configs | path is-link) {
            print -e $'($in_configs) is already properly symlinked'
            return $in_configs
        }
        let old_configs = $'($in_configs)-old'
        if ($old_configs | path exists) {
            print -e $'removing folder from previously canceled script? ($old_configs)'
            rm -r $old_configs
        }
        if ($in_configs | path exists) {
            print -e $'mv: ($in_configs) -> ($old_configs)'
            mv $in_configs $old_configs
        }
        print -e $'attempting to symlink: ($in_configs) -> ($in_dotfiles)'
        let res = (ln -s $in_configs $in_dotfiles)
        if ($old_configs | path exists) {
            print -e $'rm: ($old_configs)'
            rm -r $old_configs
        }
        $res
    }
}
