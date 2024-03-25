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
    ]
)

if (which starship | length | into bool) {
    ^starship init nu | save -f ($generated | path join "starship.nu")
    $postconfig_content ++= `use $"($generated)/starship.nu"`
}

if (which atuin | length | into bool) {
    ^atuin init nu | save -f ($generated | path join "atuin.nu")
    $postconfig_content ++= `source $"($generated)/atuin.nu"`
}

$postconfig_content | str join "\n" | save -f $postconfig

let clipboard_url = 'https://github.com/nushell/nu_scripts/raw/main/modules/system/mod.nu'
let clipboard_nu = $scripts | path join "clipboard.nu"
if not ($clipboard_nu | path exists) {
    http get $clipboard_url | save $clipboard_nu
}
