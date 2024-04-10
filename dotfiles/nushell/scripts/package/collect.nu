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
    )
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
}
