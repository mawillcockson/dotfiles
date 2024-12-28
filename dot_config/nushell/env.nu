use consts.nu [
    nu_log_format,
    nu_log_date_format,
    preconfig,
]

# NOTE::BUG These three don't seem to be set in the resulting interactive environment
# There's two `%ANSI_STOP%` in case there's an unterminated ansi sequence in the message
$env.NU_LOG_FORMAT = ($env | get NU_LOG_FORMAT? | default $nu_log_format)
$env.NU_LOG_DATE_FORMAT = ($env | get NU_LOG_DATE_FORMAT? | default $nu_log_date_format)
# set to `debug` for extra output
$env.NU_LOG_LEVEL = ($env | get NU_LOG_LEVEL? | default 'info')

if ('NVIM' in $env) and (which nvr | is-not-empty) {
    $env.GIT_EDITOR = 'nvr -cc split --remote-wait'
}

# Incrementing SHLVL is now done automatically for interactive nu sessions
# https://www.nushell.sh/blog/2024-12-24-nushell_0_101_0.html#shlvl-toc
# $env.SHLVL = ($env | get SHLVL? | default '0' | into int) + 1

$env.HOME = ($env | get HOME? USERPROFILE? | compact | first | default $nu.home-path)

$env.EGET_CONFIG = ($env.XDG_CONFIG_HOME | path join '.eget.toml')
$env.EGET_BIN = ($env.HOME | path join 'apps' 'eget-bin')
# make the directory here so that an non-existent directory isn't removed from
# any $PATHs
mkdir $env.EGET_BIN
use eget_setup.nu
eget_setup

let zint_dir = ($env.HOME | path join 'apps' 'zint')
let atuin_dir = ($env.HOME | path join '.atuin' 'bin')
let cargo_dir = ($env | get CARGO_HOME? | default ($env.HOME | path join '.cargo') | path join 'bin')

let sbins = (
    [
        '/sbin',
        '/usr/sbin',
        '/usr/local/sbin',
    ] |
    filter {path exists}
)

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
    | append $zint_dir
    | append $atuin_dir
    | append $cargo_dir
    | append $sbins
    | uniq
    | path expand
)

if (which fnm | is-not-empty) {
  try {
    fnm env --json | from json
  } catch {{}}
} else {{}} | load-env
$env.PATH = if ('FNM_MULTISHELL_PATH' in $env) {
  let maybe_bin = ($env.FNM_MULTISHELL_PATH | path join 'bin')
  $env.PATH |
  prepend (if ($maybe_bin | path exists) {$maybe_bin} else {$env.FNM_MULTISHELL_PATH})
} else {$env.PATH}


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
