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
        'const version_file = $"($generated)/version.nuon"',
        'if not ($version_file | path exists) {',
        '    $env.NU_VERSION | to nuon | save $version_file',
        '} else if (open $version_file | $in < $env.NU_VERSION) {',
        '    print -e "updating generated defaults for new version of nushell"',
        '    config env --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_env.nu"',
        '    config nu --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_config.nu"',
        '    $env.NU_VERSION | to nuon | save -f $version_file',
        '}',
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

[
    ['url', 'path'];
    ['https://github.com/nushell/nu_scripts/raw/main/modules/system/mod.nu', ($scripts | path join 'clipboard.nu')]
    ['https://github.com/nushell/nushell/raw/main/crates/nu-std/testing.nu', ($scripts | path join 'testing.nu')]
] | each {|row|
    if not ($row.path | path exists) {
    http get --max-time 2 $row.url | save $row.path
}} | null
