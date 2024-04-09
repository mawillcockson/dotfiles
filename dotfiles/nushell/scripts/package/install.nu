use package/data.nu
use package/manager.nu
use package/search.nu
use std [log]

# uses the package data to install a package
export def main [
    # optional name of the package
    name?: string,
] {
    let source = $in
    let platform = ($nu.os-info.name)
    let package_managers = (
        $env
        | get PACKAGE_MANAGER_DATA?
        | default (manager generate-data)
        | get ([{'value': ($platform), 'optional': true}] | into cell-path)
        | if ($in | is-empty) {return (error make {
            'msg': $'no package managers for platform ($platform | to nuon)!',
        })} else {$in}
    )
    if not (($source | is-empty) xor ($name | is-empty)) {
        return (error make {
            'msg': 'need either name or a piped package data set',
        })
    }
    let packages = (
        $source
        | default (search --exact ($name | default ''))
        | transpose name install
    )
    $packages | filter {|it|(
        $it.install.install
        | get ([{'value': ($platform), 'optional': true}] | into cell-path)
        | is-empty
    )} | each {|it| log error $'no method to install ($it.name) on ($platform)'} | if ($in | length) > 0 {
        return (error make {
            'msg': 'missing method to install some packages on this platform',
    })}
    if ($packages | is-empty) {
        return (error make {
            'msg': 'no packages to install',
    })}
    $packages | each {|it|
        let methods = ($it | get (['install', 'install', ($platform)] | into cell-path))
        $methods | transpose name id | each {|e|
            if $e.name not-in $package_managers { return (error make {
                'msg': $'($e.name) not a package manager: ($package_managers | columns | str join ", ")',
            })}
            {'closure': ($package_managers | get ([($e.name)] | into cell-path)), 'id': ($e.id)}
        } | first | do $in.closure $in.id
    }
}
