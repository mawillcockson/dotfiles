use std/log
use consts.nu [
    scripts,
    generated,
    postconfig,
    platform,
]

# This file is mainly used for generating and saving init scripts that, in
# other shells, would be used like `eval "$(tool completions --init)"`.
# It can be a bit fragile, and sensitive to the whims of nu

mkdir $scripts $generated

mut postconfig_content: list<string> = [
    '# the contents of this file are auto-generated in preconfig.nu, and should not be edited by hand',
    '',
]

let atuin_nu = ($generated | path join 'atuin.nu')
if (which atuin | is-not-empty) {
    # currently, atuin can automatically run the command when <Enter> is
    # pressed in other shells, but can't in nu
    # https://github.com/atuinsh/atuin/issues/1392
    # this disables atuin filling in for the up arrow
    ^atuin init --disable-up-arrow nu | save -f $atuin_nu
    $postconfig_content ++= $'source ($atuin_nu | to nuon)'
}

def --env "modify-starship-config" [modify: closure] {
    let starship_config = (
        $env |
        get STARSHIP_CONFIG? |
        default (
            $env |
            get XDG_CONFIG_HOME |
            path join 'starship' 'starship.toml'
        )
    )
    if not ($starship_config | path exists) {
        return (error make {
            'msg': $'cannot find starship config in expected location -> ($starship_config | to nuon)',
        })
    }

    let pattern = 'starship-(?P<descriminator>...)-(?P<num>\d+).toml'
    let modified_config = (
        if ($starship_config | path basename) =~ $pattern {
            $starship_config |
            path dirname |
            path join (
                $starship_config |
                path basename |
                parse --regex $pattern |
                first |
                into int num |
                update num {|rec| $rec.num + 1 } |
                $'starship-($in.descriminator)-($in.num).toml'
            )
        } else {
            let tmp = (
                $starship_config |
                path parse |
                update parent {|rec| $rec.parent | path expand --strict } |
                mktemp --suffix $'.($in.extension)' --tmpdir $'($in.stem)-XXX'
                #mktemp --suffix $'.($in.extension)' --tmpdir-path $in.parent $'($in.stem)-XXX'
            )
            let new = (
                $tmp |
                path basename --replace (
                    $tmp |
                    path parse |
                    $'($in.stem)-1.($in.extension)'
                )
            )
            try { mv $tmp $new } catch {|err| log error $'could not move temp starship config -> ($err.msg)' }
            $new
        }
    )

    open $starship_config |
    do $modify |
    into record |
    to toml |
    save -f $modified_config

    $env.STARSHIP_CONFIG = $modified_config

    return {
        'original': $starship_config,
        'modified': $modified_config,
    }
}

let starship_nu = ($generated | path join 'starship.nu')
if (which starship | is-not-empty) {
    ^starship init nu | save -f $starship_nu
    # NOTE::BUG using `overlay use` instead of `source` causes very weird issues
    $postconfig_content ++= $'source ($starship_nu | to nuon)'

    # $env.NU_LOG_LEVEL = 'debug'
    try {
        modify-starship-config {||
            update custom.git_email.shell {|rec|
                $rec.custom.git_email.shell |
                skip 1 |
                prepend (
                    which 'git' |
                    get 0?.path? |
                    default (
                        $rec.custom.git_email.shell |
                        first
                    ) # starship won't run a nonexistent command
                )
            } |
            match ($platform) {
                'android' => { reject battery? },
                _ => { tee { log debug $'no modifications for platform -> ($platform | to nuon)' } },
            }
        }
    } catch {|err| log error $'problem with modifying starship config -> ($err.msg)' }
}


$env.ASDF_DIR = ($env.HOME | path join '.asdf')
let asdf_nu = ($env.ASDF_DIR | path join 'asdf.nu')
if ($asdf_nu | path exists) {
    if (nu-check $asdf_nu) {
        $postconfig_content ++= $'source ($asdf_nu)'
    } else {
        print -e $'issue with asdf.nu -> ($asdf_nu)'
    }
}


let clipboard_nu = ($scripts | path join 'clipboard.nu')
if ($clipboard_nu | path exists) {
    if not (nu-check --as-module $clipboard_nu) {
        print -e 'issue with clipboard, not including'
    } else {
        $postconfig_content ++= $'export use ($clipboard_nu | to nuon)'
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

let start_ssh_nu = ($scripts | path join 'start-ssh.nu')
if ($start_ssh_nu | path exists) {
    if not (nu-check --as-module $start_ssh_nu) {
        print -e 'issue with start-ssh, not including'
    } else {
        $postconfig_content ++= $'export use ($start_ssh_nu | to nuon)'
    }
}

let dt_nu = ($scripts | path join 'dt.nu')
if ($dt_nu | path exists) {
    if not (nu-check --as-module $dt_nu) {
        print -e 'issue with dt.nu, not including'
    } else {
        $postconfig_content ++= $'export use ($dt_nu | to nuon)'
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
    print -e $"problem with postconfig.nu content; saved to -> ($postconfig_issue | to nuon)"
    $postconfig_content | save -f $postconfig_issue
    echo "" | save -f $postconfig
}

let nu_version = (version | into int --radix 10 major minor patch)
let timeout = (
    2 |
    if ($nu_version.major >= 0) and ($nu_version.minor >= 100) and ($nu_version.patch >= 0) {
        $in | into duration --unit sec
    } else {$in}
)
[
    ['url', 'path'];
    ['https://github.com/nushell/nu_scripts/raw/main/modules/system/mod.nu', ($scripts | path join 'clipboard.nu')]
    ['https://github.com/nushell/nushell/raw/main/crates/nu-std/testing.nu', ($scripts | path join 'testing.nu')]
] | each {|row|
    if not ($row.path | path exists) {
    http get --max-time $timeout $row.url | save $row.path
}} | null
