use std/log

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

if (which starship | is-not-empty) {
    use consts.nu [
        autoload,
        platform,
    ]

    ^starship init nu | save -f ($autoload | path join '54_starship_generated_setup.nu')

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
} else {
    log warning 'starship executable not found'
} |
null
