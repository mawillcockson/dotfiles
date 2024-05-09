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
        'let nu_version = version | get version',
        'if not ($version_file | path exists) {',
        '    $nu_version | to nuon | save $version_file',
        '} else if (open $version_file | $in < $nu_version) {',
        '    print -e "updating generated defaults for new version of nushell"',
        '    config env --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_env.nu"',
        '    config nu --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_config.nu"',
        '    $nu_version | to nuon | save -f $version_file',
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
    # NOTE::BUG using `overlay use` instead of `source` causes very weird issues
    $postconfig_content ++= `source $"($generated)/starship.nu"`
}


let clipboard = ($scripts | path join 'clipboard.nu')
if ($clipboard | path exists) {
    if not (nu-check --as-module $clipboard) {
        print -e 'issue with clipboard, not including'
    } else {
        $postconfig_content ++= $"export use ($clipboard | to nuon)"
    }
}

#let utils = ($scripts | path join 'utils.nu')
#if ($utils | path exists) {
#    if not (nu-check --as-module $utils) {
#        print -e 'issue with utils, not including'
#    } else {
#        $postconfig_content ++= $"export use ($utils | to nuon)"
#    }
#}

$postconfig_content ++= `export use std`

let start_ssh = ($scripts | path join 'start-ssh.nu')
if ($start_ssh | path exists) {
    if not (nu-check --as-module $start_ssh) {
        print -e 'issue with start-ssh, not including'
    } else {
        $postconfig_content ++= $"export use ($start_ssh | to nuon)"
    }
}

# package module
# NOTE: should make a table to add things in a for loop
#overlay use --prefix --reload package
#overlay use --prefix --reload $default_package_manager_data_path as 'package manager data'
#overlay use --prefix --reload $default_package_customs_path as 'package customs data'
# NOTE: this doesn't work, probably because of references to utils.nu
#let package = ($scripts | path join 'package')
#if ($package | path exists) {
#    if not (nu-check $package) {
#        print -e 'issue with package module, not including'
#    } else {
#        $postconfig_content ++= $"export use ($package | to nuon)"
#    }
#}


let postconfig_content = ($postconfig_content | append "\n" | str join "\n")
if ($postconfig_content | nu-check) {
    $postconfig_content | save -f $postconfig
} else {
    let postconfig_issue = $postconfig | path dirname | path join 'postconfig-issue.nu'
    print -e $"problem with postconfig.nu content\nsaved to\n($postconfig_issue | to nuon)"
    $postconfig_content | save -f $postconfig_issue
    echo "" | save -f $postconfig
}

[
    ['url', 'path'];
    ['https://github.com/nushell/nu_scripts/raw/main/modules/system/mod.nu', ($scripts | path join 'clipboard.nu')]
    ['https://github.com/nushell/nushell/raw/main/crates/nu-std/testing.nu', ($scripts | path join 'testing.nu')]
] | each {|row|
    if not ($row.path | path exists) {
    http get --max-time 2 $row.url | save $row.path
}} | null
