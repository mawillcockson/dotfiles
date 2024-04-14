use package/data.nu
use package/manager.nu
use package/search.nu
use std [log]
use utils.nu ["get c-p"]

const platform = ($nu.os-info.name)

# uses the package data to install a package
export def main [
    # optional name of the package
    name?: string,
    # for internal use
    --recursive-package-list: list<string>,
] {
    let source = $in
    if not (($source | is-empty) xor ($name | is-empty)) {
        return (error make {
            'msg': 'need either name or a piped package data set',
        })
    }
    let package_managers = (
        $env
        | get PACKAGE_MANAGER_DATA?
        | default (manager generate-data)
        | get c-p --optional [($platform)]
    )
    if ($package_managers | is-empty) {
        log warning $'no package managers for platform ($platform | to nuon)'
    }
    let packages = (
        $source
        | default (search --exact ($name | default ''))
        | transpose name install
    )
    $packages |
        filter {|it|(
            $it.install.install
            | get c-p --optional [($platform)]
            | is-empty
        )} |
        each {|it| log error $'no method to install ($it.name) on ($platform)'} |
        if ($in | length) > 0 {
            return (error make {'msg': 'missing method to install some packages on this platform'})
        }
    if ($packages | is-empty) {
        log error 'no packages to install'
        return (error make {'msg': 'no packages to install'})
    }
    let method = (
        $packages
        | each {|it|
            let methods = ($it | get c-p ['install', 'install', ($platform)])
            $methods |
            transpose name id |
            filter {|e|
                if $e.name in $package_managers {true} else {
                    log debug $'unrecognized package manager ($e.name | to nuon) for platform ($platform | to nuon)'
                    false
                }
            } |
            each {|e| {
                'manager': ($e.name),
                'closure': ($package_managers | get c-p [($e.name)]),
                'id': ($e.id),
            }}
        }
        | first
    )

    # This is a recursive call, and if there's a cycle in the graph
    # like (install package) -> (install package manager A) -> (install
    # package manager B) -> (install package manager A)
    # then this command may never return 🤷
    # NOTE::BUG this is probably not the best cycle detection
    let recursive_package_list = ($recursive_package_list | default [])
    if ($method.name in $recursive_package_list) {
        let msg = $'cyclic package dependency detected: ($recursive_package_list | to nuon --indent 4)'
        log error $msg
        return (error make {'msg': $msg})
    } else {
        let recursive_package_list = ($recursive_package_list | append $method.name)
        main --recursive-package-list $recursive_package_list $method.name
    }

    do $method.closure $method.id
}
