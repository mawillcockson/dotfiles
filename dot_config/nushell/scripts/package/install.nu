use package/manager
use package/search.nu
use package/package_consts.nu [platform]
use utils.nu ["get c-p"]
use std [log]

# uses the package name or `package search` output to install package(s)
export def main [
    # optional name of the package
    name?: string,
    # for internal use
    --recursive-package-list: list<string>,
] {
    let source = $in
    log debug $'name -> ($name)'
    log debug $'--recursive-package-list -> ($recursive_package_list)'
    if not (($source | is-empty) xor ($name | is-empty)) {
        return (error make {
            'msg': 'need either name or a piped package data set, not both',
            'label': {
                'span': (metadata $name).span,
                'text': 'either this or pipe package data into this command',
            },
        })
    }
    let package_managers = (
        manager load-data
        | get c-p --optional [($platform)]
    )
    if ($package_managers | is-empty) {
        log warning $'no package managers for platform ($platform | to nuon)'
    }
    let packages = (
        if ($source | is-not-empty) {$source} else {search --exact $name}
    )

    $packages |
    filter {|it|(
        $it.install
        | get c-p --optional [($platform)]
        | is-empty
    )} |
    each {|it| log error $'no method to install ($it.name) on ($platform)'} |
    if ($in | is-not-empty) {
        return (error make {'msg': 'missing method to install some packages on this platform'})
    }

    if ($packages | is-empty) {
        log error 'no packages to install'
        return (error make {'msg': 'no packages to install'})
    }

    let methods = (
        $packages
        | each {|it|
            $it |
            get c-p ['install', ($platform)] |
            transpose name id |
            filter {|e|
                log debug $'$package_managers -> ($package_managers)'
                if $e.name in ($package_managers | columns | append ['custom']) {
                    true
                } else {
                    log debug $'unrecognized package manager ($e.name) for platform ($platform | to nuon)'
                    false
                }
            } |
            each {|e|
                if $e.name == 'custom' {
                    {
                        'manager': ($e.name),
                        'closure': ($e.id),
                        # for customs, the `id` is still passed to the above
                        # `closure`, so this passes this `install` function to
                        # the custom closure, in case it needs to be able to
                        # install stuff
                        'id': ({|id: string| main $id}),
                    }
                } else {
                    {
                        'manager': ($e.name),
                        'closure': ($package_managers | get c-p [($e.name)] | first | first),
                        'id': ($e.id),
                    }
                } |
                tee {log debug $"package record:\n($in | table -e)"}
            } |
            tee {log debug $"before rejecting customs:\n($in | table -e)"} |
            if ($in | length) > 1 {
                reject custom?
            } else {
                $in
            } |
            first
        }
    )
    log debug $"current installation candidates:\n($methods | table -e)"

    for $method in $methods {
        # This is a recursive call to install a missing package manager, which
        # may depend on a missing package manager, etc. If there's a cycle in
        # the graph like (install package) -> (install package manager A) ->
        # (install package manager B) -> (install package manager A) then this
        # command may never return 🤷
        # NOTE::BUG this is probably not the best cycle detection
        let recursive_package_list = ($recursive_package_list | default [])
        if ($method.manager != 'custom') {
            if (which $method.manager | is-empty) and ($method.manager in $recursive_package_list) {
                let msg = $'cyclic package dependency detected: ($recursive_package_list)'
                log error $msg
                return (error make {'msg': $msg})
            } else if (which $method.manager | is-empty) {
                let recursive_package_list = ($recursive_package_list | append $method.manager)
                main --recursive-package-list $recursive_package_list $method.manager
            }
        }

        log debug $'running closure for ($method.manager) with ($method.id)'
        return (do $method.closure $method.id)
    }
}
