use package/manager
use package/search.nu
use package/package_consts.nu [platform]
use utils.nu ["get c-p"]
use std/log

# uses the package name or `package search` output to install package(s)
export def main [
    # optional name of the package
    name: string,
    # for internal use
    --recursive-package-list: list<string>,
]: [
    nothing -> list<record<any>>
] {
    log debug $'name -> ($name)'

    let package_managers = (
        manager load-data
        | get c-p --optional [($platform)]
    )

    if ($package_managers | is-empty) {
        log warning $'no package managers for platform ($platform | to nuon)'
    }

    let package = (search exact $name)

    let methods = (
        $package
        | get c-p ['install', $platform]
        | transpose name id
        | where {|e|
            log debug $'$package_managers -> ($package_managers)'
            if $e.name in ($package_managers | columns | append ['custom']) {
                true
            } else {
                log debug $'unrecognized package manager ($e.name) for platform ($platform | to nuon)'
                false
            }
        }
        | each {|e|
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
        }
    )

    log debug $"before rejecting customs:\n($methods | table -e)"
    let method = (
        if ($methods.manager has 'custom' and ($methods | where manager != custom | is-not-empty)) {
            $methods | where manager != custom
        } else {
            $methods
        }
        | first
    )
    log debug $"current installation candidate:\n($method | table -e)"

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
            # NOTE::IMPROVEMENT It might be better for each package manager to
            # have a `check` closure that can return a boolean indicating
            # whether it's present or not
            let recursive_package_list = ($recursive_package_list | append
                $method.manager)
            main --recursive-package-list $recursive_package_list $method.manager
        }
    }

    log debug $'running closure for ($method.manager) with ($method.id)'
    return (do $method.closure $method.id)
}
