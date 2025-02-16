# defined in env.nu
# const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
use std/log
use utils.nu [powershell-safe]
use package/package_consts.nu [default_package_manager_data_path]

# saves package manager data, optionally to a path we specify
# if no data is provided, it automatically uses `package manager generate-data`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package manager data to
    --path: path,
] {
    let data = ($in)
    let path = ($path | default $default_package_manager_data_path)
    let bad_path = ($path | path basename --replace ($'bad-($path | path basename)'))

    let func_def = [
        r##'# this file is auto-generated'##,
        r##'# please use `package manager add --save` instead'##,
        r##''##,
        r##'# returns the package manager data'##,
        r##'export def "package-manager-load-data" [] {'##,
        r##'    use package/manager/simple_add.nu ['simple-add']'##,
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
    prepend $func_def | append ['}'] |
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
export def "load-data" [] {
    do {
        use package/package_consts.nu ['default_package_manager_data_path']
        use $default_package_manager_data_path ['package-manager-load-data']
        package-manager-load-data
    }
}

def "flatten-data" [] {
    transpose platform managers |
    update managers {|row| $row.managers | transpose manager closure } |
    flatten --all
}

export def "data-diff" [right] {
    let left = ($in)
    let left_table = ($left | flatten-data)
    let right_table = ($right | flatten-data)

    let left_only_platforms = (
        $left_table |
        where platform not-in ($right_table | get platform)
    )
    let left_table = (
        $left_table |
        where platform not-in ($left_only_platforms | get platform)
    )

    let right_only_platforms = (
        $right_table |
        where platform not-in ($left_table | get platform)
    )
    let right_table = (
        $right_table |
        where platform not-in ($right_only_platforms | get platform)
    )

    let left_only_managers = (
        $left_table |
        filter {|left_row|
            $left_row.manager not-in (
                $right_table |
                where platform == $left_row.platform |
                get manager
            )
        }
    )
    let left_table = (
        $left_table |
        filter {|left_row|
            $left_row.manager in (
                $right_table |
                where platform == $left_row.platform |
                get manager
            )
        }
    )

    let right_only_managers = (
        $right_table |
        filter {|right_row|
            $right_row.manager not-in (
                $left_table |
                where platform == $right_row.platform |
                get manager
            )
        }
    )
    let right_table = (
        $right_table |
        filter {|right_row|
            $right_row.manager in (
                $left_table |
                where platform == $right_row.platform |
                get manager
            )
        }
    )

    let left_closures = (
        $left_table |
        filter {|left_row|
            (view source $left_row.closure) not-in (
                $right_table |
                where platform == $left_row.platform and manager == $left_row.manager |
                get closure |
                each {|it| view source $it}
            )
        }
    )
    let identicals = (
        $left_table |
        filter {|left_row|
            (view source $left_row.closure) in (
                $right_table |
                where platform == $left_row.platform and manager == $left_row.manager |
                get closure |
                each {|it| view source $it}
            )
        }
    )

    let right_closures = (
        $right_table |
        filter {|right_row|
            (view source $right_row.closure) not-in (
                $left_table |
                where platform == $right_row.platform and manager == $right_row.manager |
                get closure |
                each {|it| view source $it}
            )
        }
    )

    {
        'left_only_platforms': ($left_only_platforms),
        'left_only_managers': ($left_only_managers),
        'left_closures': ($left_closures),
        'identical': ($identicals),
        'right_only_platforms': ($right_only_platforms),
        'right_only_managers': ($right_only_managers),
        'right_closures': ($right_closures),
    }
}
