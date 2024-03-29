const scripts = $'($nu.default-config-dir)/scripts'
# uses powershell to get the target of a symlink
# probably best used only on Windows, in powershell not pwsh
export def "path resolve" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null)) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = (if ($path == null) { $piped } else {$path })
    
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.4#input
    # https://stackoverflow.com/a/39350507
    return (
        $value |
        powershell -NoLogo -NonInteractive -NoProfile -Command '
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
    let target = (ls --directory --full-paths $orig_target | get name | first 1 | get 0)
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
            [($link | path dirname), ($link | path basename), $target] | str join "\u{0}" | ^powershell -NoLogo -NonInteractive -NoProfile -Command $'
            $OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding;
            $temp = $input -split [char]0x0;
            New-Item -Type ($link_type) -Path $temp[0] -Name $temp[1] -Value $temp[2]' | complete
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

export use $"($scripts)/clipboard.nu"
export def "date my-format" [] {
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}
