use package/manager.nu
use utils.nu [powershell-safe]
use std [log]

const platform = ($nu.os-info.name)

# runs collectors to collect information from package managers
export def main [
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
                    log debug $'collector ($collector_name | to nuon) not in ($rest | to nuon)'
                    false
                }
            }
        }
    )
    if ($collectors | is-empty) {
        log warning $'no matching collectors for this platform'
    }
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
    | each {|it|
        $collectors | get ([$it.name] | into cell-path) | do $in
    }
    | flatten
    )
}

# NOTE::FIX find better place for this
const default_scoop_buckets = ['main', 'extras', 'nerd-fonts']

export def "windows scoop" [] {
    (powershell-safe -c 'scoop export').stdout | from json | tee {||
        $in.buckets.0 | filter {|it| $it.Name not-in $default_scoop_buckets} | each {|it|
            log warning $'bucket ($it.Name | to nuon) not in default list: ($default_scoop_buckets | str join ", ")'
        }
    } | get apps? | default [[]] | get 0 | each {|it|
        # NOTE::BUG I don't like that an error is thrown if the below line is commented out
        let a = (0)
        package add $it.Name {'windows': {'scoop': $it.Name}} --tags ['collector']
    } | get data
}

export def "generate-collectors" [] {
    {
        'windows': {
            'scoop': {|| windows scoop},
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
