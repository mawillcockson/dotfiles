# defined in env.nu
# const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
use std [log]
use utils.nu [powershell-safe]

# provide a closure that implements installing a single package with the named
# package manager
#
# this returns a data structure that `package manager save` can persist to disk
export def add [
    # the default for platform is whatever the current platform is
    --platform: string = ($nu.os-info.name),
    # the name of the package manager, used in `package add`
    name: string,
    # the closure that is passed a package id, and expected to install the package
    closure: closure,
] {
    # the insert command itself takes a closure as the second argument, so the
    # closure has to be wrapped in a closure that, when executed, returns the
    # $closure
    default {} | insert ([$platform, $name] | into cell-path) {|row| $closure}
}

# saves package manager data, optionally to a path we specify
# if no data is provided, it automatically uses `package manager generate-data`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package manager data to
    --path: path,
] {
    # intentionally leaving this as `default` so that it runs each time, so
    # slow performance will bother me
    let data = default (generate-data)
    let path = ($path | default (data-path))
    let bad_path = ($path | path basename --replace ($'bad-($path | path basename)'))
    mkdir ($path | path dirname)

    let func_def = [
        `# this file is auto-generated`,
        `# please edit scripts/package/manager.nu instead`,
        ``,
        `# returns the package manager data`,
        `export def "package-manager-load-data" [] {`,
    ]

    $data | transpose platform_name install |
    update install {|row| $row.install | transpose package_manager_name closure | update closure {|row| view source ($row.closure)}} |
    each {|it|
        $'    ($it.platform_name | to nuon): {' | append ($it.install | each {|e|
                $'        ($e.package_manager_name | to nuon): ($e.closure),'
        }) | append '    },'
    } | flatten | prepend ['{'] | append ['}'] |
    prepend $func_def | append [`}`] |
    str join "\n" |
    if not ($in | nu-check --as-module) {
        # have this be first, otherwise $in becomes empty
        $in | save -f $bad_path
        log error $'generated managers.nu is not a valid nu module!'

        return (error make {
            'msg': $'generated .nu file is not valid -> ($path | default (data-path))',
        })
    } else {
        # have this be first, otherwise $in becomes empty
        $in | save -f $path
        log info $'saving package manager data to ($path)'
    }
}

# load the package manager data from the default path
export def "load-data" [
] {
    # if ($path | is-not-empty) and (not ($path | path exists)) {
    #     return (error make {
    #         'msg': 'path must point to an existing file',
    #         'label': {
    #             'text': 'file does not exist',
    #             'span': ($path | metadata).span,
    #         },
    #         'help': 'use `package manager save-data --path` to create the file',
    #     )}
    # }
    # let path = ($path | default (data-path))

    # wrap in a do block to ensure this doesn't affect the current scope, just
    # in case
    do {
        use package/consts.nu ['default_package_manager_data_path']
        use $default_package_manager_data_path ['package-manager-load-data']
        package-manager-load-data
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
    # add --platform 'platform' 'manager' {|id: string| print $'installing ($id)'}
    add --platform 'windows' 'scoop' {|id: string| $id | powershell-safe -c $"scoop install $Input"} |
    add --platform 'windows' 'winget' {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity} |
    add --platform 'windows' 'pipx' {|id: string| ^pipx install $id} |
    add --platform 'android' 'pkg' {|id: string| ^pkg install $id} |
    add --platform 'windows' 'eget' {|id: string| ^eget /quiet $id}
}
