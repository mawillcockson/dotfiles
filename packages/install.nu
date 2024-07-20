const dotfiles = $'($nu.home-path)/projects/dotfiles'
const scripts = $'($dotfiles)/dotfiles/nushell/scripts'
const utils = $'($scripts)/utils.nu'
export use $utils
const packages = $'($dotfiles)/dotfiles/packages'
const windows_install = $'($packages)/windows_install.nu'

match $nu.os-info.name {
    'windows' => {
        source $windows_install
    },
    _ => {
        return (error make {'msg': $'platform not implemented: ($nu.os-info.name)'})
    },
}
