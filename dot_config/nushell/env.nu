use consts.nu [
    default_env,
    default_package_manager_data_path,
    default_package_data_path,
    preconfig,
]

do { use gen_defaults.nu; gen_defaults }

source $default_env

[
    $default_package_manager_data_path,
    $default_package_data_path,
] | each {|it|
    if not ($it | path exists) {
        mkdir ($it | path dirname)
        touch $it
    } else if (not (nu-check $it)) {
        use std [log]
        log error $'not a valid nu module! -> ($it)'
        log warning $'truncating -> ($it)'
        echo '' | save -f $it
    }
} | null

if ('NVIM' in $env) and (which nvr | is-not-empty) {
    $env.GIT_EDITOR = 'nvr -cc split --remote-wait'
}

# NOTE::BUG These two don't seem to be set in the resulting interactive environment
# There's two `%ANSI_STOP%` in case there's an unterminated ansi sequence in the message
$env.NU_LOG_FORMAT = '%ANSI_START%%DATE% [%LEVEL%]%ANSI_STOP% - %MSG%%ANSI_STOP%'
# set to `debug` for extra output
$env.NU_LOG_LEVEL = 'info'

$env.SHLVL = ($env | get SHLVL? | default 0 | into int | $in + 1)

$env.HOME = ($env | get HOME? USERPROFILE? | compact | first | default $nu.home-path)

$env.EGET_CONFIG = ($env.XDG_CONFIG_HOME | path join '.eget.toml')
$env.EGET_BIN = ($env.HOME | path join 'apps' 'eget-bin')
mkdir $env.EGET_BIN
{
    'global': {
        'target': ($env.EGET_BIN),
        'upgrade_only': true,
    },
} |
insert 'FiloSottile/age' {'asset_filters': ['^.proof']} |
match $nu.os-info.name {
    'windows' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean.exe']} |
        insert 'getsops/sops' {'asset_filters': ['.exe', '^.json']} |
        insert 'twpayne/chezmoi' {'asset_filters': ['.zip']} |
        insert 'jtroo/kanata' {'asset_filters': ['winIOv2.exe']}
    },
    'linux' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-ubuntu']} |
        insert 'jtroo/kanata' {'asset_filters': ['kanata', '^.']} |
        insert 'neovide/neovide' {'asset_filters': ['^.zip']} |
        insert 'sharkdp/fd' {'asset_filters': ['gnu']}
    },
    'macos' => {
        insert 'nalgeon/sqlite' {'asset_filters': ['sqlean-macos']}
    },
    _ => {
        insert 'nalgeon/sqlite' {'download_source': true}
    },
} | to toml | prepend ['# this file is auto-generated in env.nu', ''] | str join "\n" | save -f $env.EGET_CONFIG

let zint_dir = ($env.HOME | path join 'apps' 'zint')

$env.PATH = (
    $env
    # NOTE::IMPROVEMENT I would like caseinsensitive environment variables
    | get PATH? Path?
    | first
    | if ($in | describe | str replace --regex '<.*' '') == 'string' {
        $in | split row (char env_sep)
    } else {$in}
    | append ($env.EGET_BIN)
    | if ('C:\Exercism' | path exists) {append 'C:\Exercism'} else {$in}
    | if ($zint_dir | path exists) {append $zint_dir} else {$in}
    | uniq
    | path expand
)

use pyenv_setup.nu
pyenv_setup

# generate stuff that can then be sourced in config.nu
# this is done like this so that the correct directories can be created in
# preconfig.nu and then sourced in postconfig.nu, and so that variables defined
# here have already taken effect for nu
source $preconfig
#if ($preconfig | path exists) {
#    nu $preconfig
#}
