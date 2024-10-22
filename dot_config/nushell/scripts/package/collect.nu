use package/data
use package/manager
use utils.nu [powershell-safe]
use package/package_consts.nu [platform]
use std/log


# runs collectors to collect information from package managers
export def "collect-all" [
    # the collectors to use (defaults to all)
    ...rest: string,
] {
    let collectors = (
        generate-collectors
        | get ([{'value': ($platform), 'optional': true}] | into cell-path)
        | default {}
        | filter {|it|
            if ($rest | is-empty) {true} else {
                let collector_name = ($it | columns | first)
                if ($collector_name in $rest) {true} else {
                    log debug $'collector ($collector_name) not in ($rest)'
                    false
                }
            }
        }
    )
    if ($collectors | is-empty) {
        log warning $'no matching collectors for this platform: ($platform)'
    }
    let collectors = ($collectors | first)
    let package_managers = (
        manager generate-data
        | get ([{'value': ($platform), 'optional': true}] | into cell-path)
        | default {}
    )
    (
    $package_managers
    | transpose name closure
    | filter {|it|
        if $it.name not-in $collectors {
            log warning $'package manager ($it.name | to nuon) has no associated collector'
            false
        } else { true }
    }
    | each ({|it|
        $collectors | get ([$it.name] | into cell-path) | do $in
    })
    | flatten
    )
}

# NOTE::FIX find better place for this
const default_scoop_buckets = ['main', 'extras', 'nerd-fonts']

export def "windows scoop" [] {
    if (which scoop | length) <= 0 {
        log info 'scoop not found'
        return []
    }
    (
        (powershell-safe -c 'scoop export').stdout
        | from json
        | tee {||
            $in.buckets.0 | filter {|it|
                $it.Name not-in $default_scoop_buckets
            } | each ({|it|
                log warning $'bucket ($it.Name | to nuon) not in default list: ($default_scoop_buckets | str join ", ")'
            })
        }
        | get apps?
        | default [[]]
        | get 0
        | each ({|it|
            # NOTE::BUG I don't like that an error is thrown if the below line is commented out
            let a = (0)
            data add $it.Name {'windows': {'scoop': ($it.Name)}} --tags ['collector']
        })
    )
}

export def "windows winget" [] {
    if (which winget | length) <= 0 {
        log info 'winget not found'
        return []
    }
    let temp = (mktemp --suffix '.json')
    ^winget export --source winget --accept-source-agreements --disable-interactivity --output $temp
    let out = (open --raw $temp | from json)
    rm $temp
    $out.Sources.0.Packages | each ({|it|
        let name = (
            $it.PackageIdentifier
            | parse '{a}.{b}'
            | first
            | if ($in.a == $in.b) {$in.a | str downcase} else {$it.PackageIdentifier}
        )
        data add $name {'windows': {'winget': ($it.PackageIdentifier)}} --tags ['collector']
    })
}

export def "any pipx" [] {
    let pipx = (
        if (which pipx | length) >= 0 {which pipx | get 0.path}
        else if ((which python | length) >= 0) and ((^python -c '
try:
    import pipx
except ImportError:
    print("no")
else:
    print("yes")') == 'yes') {^python -c 'import sys; print(sys.executable)'}
        else {
            log info 'pipx not found'
            return []
        }
    )
    let out = (
        ^pipx -qqq list
        | decode 'utf8'
        | lines
        | skip until {|it| $it starts-with ' '}
    )
    mut group = (0)
    mut groups = []
    for $line in $out {
        $group += (if not ($line starts-with '    -') { 1 } else { 0 })
        $groups ++= $group
    }
    let groups = ($groups | enumerate)
    (
        $out
        | enumerate
        | insert group {|row| $groups | get ([$row.index, 'item'] | into cell-path)}
        | group-by --to-table group
        | each ({|it|
            log debug (try { $it | get items | first | get item })
            let package_name = (
                $it
                | get items
                | first
                | get item
                | parse --regex `^\s+package (?P<name>.*) [\S]+, installed using Python \d\.\d{1,2}\.\d{1,2}$`
                | get 0.name
            )
            log debug ($package_name | debug)
            data add $package_name {($platform): {'pipx': ($package_name)}} --tags ['collector']
        })
    )
}

export def "generate-collectors" [] {
    {
        'windows': {
            'scoop': {|| windows scoop},
            'winget': {|| windows winget},
            'pipx': {|| any pipx},
        },
    }
}

export def "format-as-commands" [] {
    each {|it|
        let name = ($it | columns | first)
        let info = ($it | get ([$name] | into cell-path))
        let install_str = ($info.install | transpose platform install | each {|it|
            $it.install | transpose manager id | each {|e|
                if $e.manager == 'custom' {
                    $'"custom": ($e.id)'
                } else {
                    $'($e.manager | to nuon): ($e.id | to nuon)'
                }
            } | str join ', ' | prepend [$'($it.platform | to nuon): {'] | append '}' | str join ''
        } | str join ', ' | prepend ['{'] | append '}' | str join '')
        if not ($install_str | nu-check) { return (error make {
            'msg': 'install_str is not valid nu'
        })}
        let command = (
        [
            'package add',
            ($name | to nuon),
            ($install_str),
        ]
        | if ($info.tags | is-not-empty) {$in | append ['--tags', ($info.tags | to nuon)]} else {$in}
        | if ($info.search_help | is-not-empty) {$in | append ['--search-help', ($info.search_help | to nuon)]} else {$in}
        | if ($info.reasons | is-not-empty) {$in | append ['--reasons', ($info.reasons | to nuon)]} else {$in}
        | if ($info.links | is-not-empty) {$in | append ['--links', ($info.links | to nuon)]} else {$in}
        | str join ' '
        )
        if not ($command | nu-check) { return (error make {
            'msg': 'command is not valid nu'
        })}
        $command
    }
}
