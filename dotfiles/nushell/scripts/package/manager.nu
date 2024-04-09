# defined in env.nu
# const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'

# provide a closure that implements installing a single package with the named
# package manager
#
# this returns a data structure that `package manager save` can persist to disk
export def add [
    # the default for platform is whatever the current platform is
    --platform: string,
    # the name of the package manager, used in `package add`
    name: string,
    # the closure that is passed a package id, and expected to install the package
    closure: closure,
] {
    # the insert command itself takes a closure as the second argument, so the
    # closure has to be wrapped in a closure that, when executed, returns the
    # $closure
    default {} | insert ([($platform | default ($nu.os-info.name)), $name] | into cell-path) {|row| $closure}
}

# saves package manager data, optionally to a path we specify
# if no data is provided, it automatically uses `package manager generate-data`
export def "save-data" [
    # optional path of where to save the package manager data to
    --path: path,
] {
    default (generate-data) | transpose platform_name install |
    update install {|row| $row.install | transpose package_manager_name closure | update closure {|row| view source ($row.closure)}} |
    each {|it|
        $'    ($it.platform_name | to nuon): {' | append ($it.install | each {|e|
                $'        ($e.package_manager_name | to nuon): ($e.closure),'
        }) | append '    },'
    } | flatten | prepend [
        `# this file is auto-generated`,
        `# please edit scripts/package/manager.nu instead`,
        ``,
        `# loads the package manager data into memory`,
        `export-env { export def "package manager data" [] {{`,
    ] | append [
        `}}`,
        `$env.PACKAGE_MANAGER_DATA = (package manager data)`,
        `}`,
    ] | str join "\n" | save -f ($path | default (
        if ((data-path) | path dirname | path exists) == true {
            (data-path)
        } else {
            mkdir ((data-path) | path dirname)
            (data-path)
        }
    ))
    if not (nu-check ($path | default (data-path))) {
        use std [log]
        log error $'generated managers.nu is not valid!'
        return (error make {
            'msg': $'generated .nu file is not valid -> ($path | default (data-path))',
        })
    }
}

# returns the path to the package manager data
export def "data-path" [] {
    (
        scope variables
        | where name == '$default_package_manager_data_path'
        | get value?
        | compact --empty # sometimes the variable's value is an empty string
        | default [] # sometimes the value returned by `get` is an empty list, and not `null`
        | append $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
        | first
        | if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

# generate all the package manager data
#
# modify this function to register more package managers
export def "generate-data" [] {
    add --platform 'windows' 'scoop' {|id: string| ^scoop install $id} |
    add --platform 'windows' 'winget' {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity} |
    add --platform 'android' 'pkg' {|id: string| ^pkg install $id}
}
