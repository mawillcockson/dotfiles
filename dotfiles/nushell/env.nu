const default_env = $"($nu.default-config-dir)/scripts/generated/default_env.nu"
source $default_env

# mirrored in package submodules
const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
const default_package_data_path = $'($nu.default-config-dir)/scripts/generated/package/data.nuon'
const default_package_customs_path = $'($nu.default-config-dir)/scripts/generated/package/customs.nu'
[
    $default_package_manager_data_path,
    $default_package_data_path,
    $default_package_customs_path,
] | each {|it|
    if not ($it | path exists) {
        mkdir ($it | path dirname)
        touch $it
    } else if ($it | str ends-with '.nu') and (not (nu-check $it)) {
        use std [log]
        log error $'not a valid .nu file! -> ($it)'
        log warning 'truncating it'
        echo '' | save -f $it
    }
}

if ('NVIM' in $env) and (which nvr | is-not-empty) {
    $env.GIT_EDITOR = 'nvr -cc split --remote-wait'
}

# NOTE::BUG These two don't seem to be set in the resulting interactive environment
# There's two `%ANSI_STOP%` in case there's an unterminated ansi sequence in the message
$env.NU_LOG_FORMAT = '%ANSI_START%%DATE% [%LEVEL%]%ANSI_STOP% - %MSG%%ANSI_STOP%'
# set to `debug` for extra output
$env.NU_LOG_LEVEL = 'info'

$env.HOME = ($env | get HOME? USERPROFILE? | compact | first | default $nu.home-path)

let dotfiles = ($env.HOME | path join 'projects' 'dotfiles' 'dotfiles')

$env.EGET_CONFIG = ($dotfiles | path join '.eget.toml')
let eget_bin = ($env.HOME | path join 'apps' 'eget-bin')
mkdir $eget_bin
{
    'global': {
        'target': ($eget_bin),
        'upgrade_only': true,
    },
} | match $nu.os-info.name {
    'windows' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean.exe']} |
        insert 'getsops/sops' {'asset_filters': ['.exe', '^.json']}
    },
    'linux' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-ubuntu']}
    },
    'macos' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-macos']}
    },
    _ => {
        insert 'nalgeon/sqlite' {'download_source': true}
    },
} | to toml | prepend ['# this file is auto-generated in env.nu', ''] | str join "\n" | save -f $env.EGET_CONFIG

$env.PATH = ($env.PATH | split row (char env_sep)
    | append ($eget_bin)
    | append 'C:\Exercism'
    | uniq
    | path expand
)

# generate stuff that can then be sourced in config.nu
let preconfig = $nu.default-config-dir | path join "preconfig.nu"
if ($preconfig | path exists) {
    nu $preconfig
}
