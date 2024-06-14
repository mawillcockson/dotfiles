# defined in env.nu
# const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
use std [log]
use utils.nu [powershell-safe]
export use package/manager_add.nu [add, generate-data]

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
        `    use package/manager_add.nu ['add']`,
    ]

    $data | transpose platform_name install |
    update install {|row| $row.install | transpose package_manager_name closure | update closure {|row| view source ($row.closure)}} |
    each {|row|
        $row.install | each {|it|
            $'    add --platform ($row.platform_name | to nuon) ($it.package_manager_name | to nuon) ($it.closure)'
        } |
        str join " |\n"
    } | str join " |\n" |
    tee {$in | null} | # NOTE::BUG without this line, an extra newline is inserted into the string
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
