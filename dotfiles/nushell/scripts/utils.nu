const scripts = $'($nu.default-config-dir)/scripts'
# uses powershell to get the target of a symlink
# probably best used only on Windows, in powershell not pwsh
export def "path resolve" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = (if ($path == null) { $piped } else {$path })
    
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.4#input
    # https://stackoverflow.com/a/39350507
    return (
        $value |
        ^powershell -NoLogo -NonInteractive -NoProfile -Command '
            $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding;
            Get-Item $input | Select-Object -ExpandProperty Target' |
        decode 'utf8'
    )
}

# checks if the path is a directory
# can only accept an argument or piped data, not both
export def "path is-link" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = (if ($path == null) { $piped } else { $path })

    if not ($value | path exists) {
        return false
    }
    return ($value | path type | $in == 'symlink')
}

# checks if the path is a file
# can only accept an argument or piped data, not both
export def "path is-file" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = if ($path == null) { $piped } else { $path }

    if not ($value | path exists) {
        return false
    }
    return ($value | path type | $in == 'file')
}

# checks if the path is a directory
# can only accept an argument or piped data, not both
export def "path is-dir" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = if ($path == null) { $piped } else { $path }

    if not ($value | path exists) {
        return false
    }
    return ($value | path type | $in == 'dir')
}

# tries to make a symbolic link
# on windows, this can only be for directories, unless we're a privileged user
export def "ln -s" [
    link: string # path to create link at (does not yet exist)
    orig_target: string # path the symbolic link will point at (does exist)
] {
    let span = {'link': (metadata $link).span, 'target': (metadata $orig_target).span}

    if not ($orig_target | path exists) {
        return (error make {
            'msg': 'the target of the symbolic link does not currently exist',
            'label': {
                'text': $'missing ($orig_target | path type)'
                'span': $span.target,
            },
        })
    }
    if ($link | path exists) {
        return (error make {
            'msg': 'a filesystem entry already exists at the location I should be making a link',
            'label': {
                'text': $'a ($link | path type) already exists',
                'span': $span.link,
            },
        })
    }
    let target = (ls --directory --full-paths $orig_target | get 0.name)
    let res = match $nu.os-info.name {
        'windows' => {
            let link_type = (match ($target | path type) {
                'file' => {
                    if not (is-admin) {
                        print -e `symlinking to a file on windows is usually only possible if you're running with administrator privileges; normally, only directory junctions are allowed`
                    }
                    'SymbolicLink'
                },
                'symlink' => {
                    print -e `I have no idea if this will work`
                    'SymbolicLink'
                },
                'dir' => { 'Junction' },
                _ => {return (error make {
                    'msg': $"'ln -s' isn't implemented for paths of type '($target | path type)'",
                    'label': {
                        'text': $"what is a '($target | path type)'",
                        'span': $span.target,
                    },
                })},
            })
            (
            [($link_type), ($link | path dirname), ($link | path basename), $target]
            | str join "\u{0}"
            | powershell-safe -c '$temp = $input -split [char]0x0;
                New-Item -Type ($temp[0]) -Path $temp[1] -Name $temp[2] -Value $temp[3]'
            )
        },
        _ => {error make {
            'msg': $"'ln -s' isn't implemented for this platform: ($nu.os-info.name)"
        }},
    }
    if ($res.exit_code != 0) {
        return (error make {
            'msg': ($res | to text)
        })
    }
    return $res
}

# uses powershell to quote a string for use in powershell
# export def "powershell quote" [str: string] {
# 
# }
# I don't know of a way to do this, but `ConvertFrom-Json -InputObject $Input`
# can be used, and then any complex object data can be piped to powershell.
# Also, this pattern can be used to pipe arbitrary, difficult-to-quote strings
# to powershell:
# ['`#$^*@', 'slightly easier to quote'] |
# str join "\u{0}" |
# ^powershell -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -Command '
# <# Put this after so that scoop has a default environment. I remember it not liking me changing $ErrorActionPreference
# # https://github.com/PowerShell/PowerShell/issues/3415#issuecomment-1354457563 #>
# if ($host.version.Major -eq 7 && $host.version.Minor -ge 4) {
#   Enable-ExperimentalFeature PSNativeCommandErrorActionPreference
# }
# Set-StrictMode -Version Latest
# $ErrorActionPreference = "Stop"
# $PSNativeCommandUseErrorActionPreference = $true
# $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
# $vars = $Input -split [char]0x0
# Write-Host $vars[0]; Write-Host $vars[1]' | decode 'utf8'

# run powershell in a way that I prefer, and in a way that's compatible with
# nushell
export def "powershell-safe" [
    # the command/script to run
    --command (-c): string,
    # reduce the safetiness (primarily for running scoop and other programs
    # written in PowerShell)
    --less-safe,
    # do not throw an error when powershell returns an error; instead, return a
    # `complete`
    --no-fail,
] {
    let piped = ($in)
    if ($command | is-empty) {return (error make {
        'msg': '--command is required',
        'label': {
            'span': (metadata $command).span,
            'text': 'missing',
        },
    })}

    let script = ([
        `$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding`,
    ] | append $command | prepend (if not $less_safe {[
            # `<# Put this after so that scoop has a default environment. I remember it not liking me changing $ErrorActionPreference`,
            # `# https://github.com/PowerShell/PowerShell/issues/3415#issuecomment-1354457563 #>`,
            # `if (($host.version.Major -eq 7) -and ($host.version.Minor -ge 4)) {`,
            # `  Enable-ExperimentalFeature PSNativeCommandErrorActionPreference`,
            # `}`,
            `Set-StrictMode -Version Latest`,
            `$ErrorActionPreference = "Stop"`,
            `$PSNativeCommandUseErrorActionPreference = $true`,
        ]}
    ))
    let args = [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'RemoteSigned',
        '-Command', ($script | str join (char crlf)),
    ]
    (
    $piped
    | run-external (if (which pwsh | length) > 0 {'pwsh'} else {'powershell'}) ...($args)
    o+e>| complete
    | if (not $no_fail) and ($in.exit_code != 0) { return (error make {
        'msg': $'powershell returned an error: ($in)',
    })} else {$in}
    )
}

export use $"($scripts)/clipboard.nu"
export def "date my-format" [] {
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}

use std
export def "log" [
    level?: string,
    msg?: string,
] {
    if ($msg == null) and ($level == null) {
        return (error make {
            'msg': 'msg is actually required',
            'label': {
                'text': 'missing msg', 'span': (metadata $msg).span,
            },
        })
    }

    let args = if ($msg == null) and ($level != null) {
        {'msg': $level, 'level': 'info'}
    } else if ($level == null) and ($msg != null) {
        {'msg': $msg, 'level': info}
    } else if ($level != null) and ($msg != null) {
        {'msg': $msg, 'level': $level}
    } else {return (error make {'msg': 'should not have been able to reach here'})}

    let $subcommand = match $args.level {
        null => 'info',
        'critical' => 'critical',
        'debug' => 'debug',
        'error' => 'error',
        'info' => 'info',
        'warning' => 'warning',
        _ => {
            return (error make {
                'msg': 'error level must be one of critical, debug, error, info, or warning; or left empty',
                'label': {
                    'text': 'invalid error level',
                    'span': (metadata $level).span,
                }
            })
        },
    }
    let color = match $subcommand {
        'critical' => 'red_reverse',
        'debug' => 'light_gray_dimmed',
        'error' => 'red',
        'info' => 'green',
        'warning' => 'yellow',
    }
    let format = $'%ANSI_START%%DATE% [(ansi $color)%LEVEL%(ansi reset)] - %MSG%%ANSI_STOP%'
    let rest = [--format $format $args.msg]
    match $subcommand {
        'critical' => (std log critical --format $format $args.msg),
        'debug' => (std log debug --format $format $args.msg),
        'error' => (std log error --format $format $args.msg),
        'info' => (std log info --format $format $args.msg),
        'warning' => (std log warning --format $format $args.msg),
    }
}

# call `get` with a cell-path
export def "get c-p" [
    # are all the path elements optional?
    --optional,
    # initial cell path required
    cell_path: list<string>,
    ...rest
] {
    let source = ($in)
    (
        $rest
        | default []
        | prepend [$cell_path]
        | each {|it|
            $source | get (
                $it
                | wrap value
                | insert optional ($optional)
                | into cell-path
            )
        }
    )
}
