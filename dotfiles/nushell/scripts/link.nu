const utils = $'($nu.default-config-dir)/scripts/utils.nu'
overlay use $utils

let configs = match $nu.os-info.name {
    'windows' => ($env.OneDrive | path join 'Documents' 'configs'),
    _ => {
        print --stderr 'not implemented for this platform'
        exit 1
    },
}
let dotfiles = match $nu.os-info.name {
    'windows' => ($env.USERPROFILE | path join 'projects' 'dotfiles' 'dotfiles'),
    _ => {
        print --stderr 'not implemented for this platform'
        exit 1
    },
}

['starship', 'nvim', 'xonsh', 'atuin', 'scoop'] | each {|name|
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
    return $res
}
