use consts.nu [
    platform,
    nu_log_format,
    nu_log_date_format,
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

let default_home_dir = (
    $nu
    | get home-path? home-dir?
    | where {path exists}
    | compact --empty
    | first
)

$env.HOME = ($env | get HOME? USERPROFILE? | compact | get 0? | default $default_home_dir)

$env.EGET_CONFIG = ($env.XDG_CONFIG_HOME | path join '.eget.toml')
$env.EGET_BIN = ($env.HOME | path join 'apps' 'eget-bin')
# make the directory here so that an non-existent directory isn't removed from
# any $PATHs
mkdir $env.EGET_BIN

# Haskell Stack
$env.STACK_LOCAL_BIN_PATH = ($env.HOME | path join 'apps' 'stack-bin')
mkdir $env.STACK_LOCAL_BIN_PATH
$env.STACK_XDG = 'true'

if ('NVIM' in $env) and (which nvr | is-not-empty) {
# if running in Neovim, use that as our editor
    $env.EDITOR = "nvr -cc split --remote-wait"
} else if (which nvim | is-not-empty) {
# otherwise use Neovim itself
    $env.EDITOR = "nvim"
}

let zint_dir = ($env.HOME | path join 'apps' 'zint')
let atuin_dir = ($env.HOME | path join '.atuin' 'bin')
let cargo_dir = ($env | get CARGO_HOME? | default ($env.HOME | path join '.cargo') | path join 'bin')

let sbins = (
    [
        '/sbin',
        '/usr/sbin',
        '/usr/local/sbin',
    ] |
    where {path exists}
)

let dot_local = ($default_home_dir | path join '.local')
# from: https://www.haskell.org/ghcup/install/#manual-installation
let ghcup_base = $dot_local
let ghcup_bin = ($ghcup_base | path join (
    match $platform {
        'windows' => 'ghcup',
        'linux' => '.ghcup',
        _ => '.ghcup',
    }
) 'bin')
match $platform {
    'windows' => {
        {
            GHCUP_MSYS2: ('~/scoop/apps/msys2/current/' | path expand),
            GHCUP_INSTALL_BASE_PREFIX: $ghcup_base,
            CABAL_DIR: ($ghcup_base | path join 'cabal'),
        }
    },
    'linux' => {
        {
            GHCUP_INSTALL_BASE_PREFIX: $ghcup_base,
            CABAL_DIR: ($ghcup_base | path join 'cabal'),
        }
    },
    _ => {
        {}
    },
} | load-env

use light-utils.nu ["path add"]

path add ...([
    ($env.EGET_BIN),
    (if ('C:\Exercism' | path exists) {'C:\Exercism'} else {null}),
    $zint_dir,
    $atuin_dir,
    $cargo_dir,
    $ghcup_bin,
    $env.STACK_LOCAL_BIN_PATH,
] | append $sbins)

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


do {
    use pyenv_setup.nu
    pyenv_setup
} | load-env
