let scripts = $nu.default-config-dir | path join "scripts"
let generated = $scripts | path join "generated"
mkdir $scripts $generated

let postconfig = $generated | path join "postconfig.nu"
let postconfig_preamble: list<string> = [
    '# the contents of this file are auto-generated in preconfig.nu, and should not be edited by hand',
    '',
]

mut postconfig_content: list<string> = (
    $postconfig_preamble
    | append [
        'const default_config_dir = $nu.default-config-dir',
        'const scripts = $"($default_config_dir)/scripts"',
        'const generated = $"($scripts)/generated"',
        'config env --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_env.nu"',
        'config nu --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_config.nu"',
    ]
)

if (which atuin | is-not-empty) {
    # currently, atuin can automatically run the command when <Enter> is
    # pressed in other shells, but can't in nu
    # https://github.com/atuinsh/atuin/issues/1392
    # this disables atuin filling in for the up arrow
    ^atuin init --disable-up-arrow nu | save -f ($generated | path join "atuin.nu")
    $postconfig_content ++= `source $"($generated)/atuin.nu"`
}

if (which starship | is-not-empty) {
    ^starship init nu | save -f ($generated | path join "starship.nu")
    $postconfig_content ++= `overlay use $"($generated)/starship.nu"`
}

$postconfig_content | str join "\n" | save -f $postconfig

let clipboard_url = 'https://github.com/nushell/nu_scripts/raw/main/modules/system/mod.nu'
let clipboard_nu = $scripts | path join "clipboard.nu"
if not ($clipboard_nu | path exists) {
    http get $clipboard_url | save $clipboard_nu
}

try {
    http get --max-time 2 'https://github.com/nushell/nushell/raw/main/crates/nu-std/testing.nu' | save -f $'($scripts)/testing.nu'
}
