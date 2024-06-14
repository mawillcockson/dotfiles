# defined in env.nu
# const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
use std [log]
use utils.nu [powershell-safe]
# this line is here purely so the function is re-exported in the expected namespace
use package/consts.nu [default_package_manager_data_path]

# saves package manager data, optionally to a path we specify
# if no data is provided, it automatically uses `package manager generate-data`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package manager data to
    --path: path,
] {
    # intentionally leaving this as `default` so that it runs each time, so
    # slow performance will bother me
    let data = default (load-data)
    let path = ($path | default $default_package_manager_data_path)
    let bad_path = ($path | path basename --replace ($'bad-($path | path basename)'))

    let func_def = [
        `# this file is auto-generated`,
        '# please use `package manager add --save` instead',
        ``,
        `# returns the package manager data`,
        `export def "package-manager-load-data" [] {`,
        `    use package/manager/simple_add.nu ['simple-add']`,
    ]

    $data | transpose platform_name install |
    update install {|row| $row.install | transpose package_manager_name closure | update closure {|row| view source ($row.closure)}} |
    each {|row|
        $row.install | each {|it|
            $'    simple-add --platform ($row.platform_name | to nuon) ($it.package_manager_name | to nuon) ($it.closure)'
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
            'msg': $'generated .nu file is not valid -> ($bad_path)',
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
    do {
        use package/consts.nu ['default_package_manager_data_path']
        use $default_package_manager_data_path ['package-manager-load-data']
        package-manager-load-data
    }
}
