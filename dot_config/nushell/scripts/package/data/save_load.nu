use std [log]
use package/package_consts.nu [platform, default_package_data_path]
use package/data/validate_data.nu [validate-data]

# saves package data, optionally to a specified path
# if no data is provided, it automatically uses `package data generate`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package data to
    --path: path,
] {
    let data = ($in)
    let path = ($path | default $default_package_data_path)
    let bad_path = ($path | path basename --replace ($'bad-($path | path basename)'))

    let func_def = [
        r##'# this file is auto-generated'##,
        r##'# please use `package add --save` instead'##,
        r##''##,
        r##'# returns the package data'##,
        r##'export def "package-data-load-data" [] {'##,
        r##'    use package/data/simple_add.nu ['simple-add']'##,
        r##'    use package/data/validate_data.nu ['validate-data']'##,
        r##''##,
    ]

    # NOTE::DEBUG
    #{example: {install: {windows: {custom: {|id: string| print $'installing ($id | to nuon)'}}}, reasons: ['testing'], tags: ['testing'], search_help: [], links: []}} |
    $data |
    validate-data |
    transpose package data |
    each {|row|
        mut command = $'    simple-add ($row.package | to nuon) ($row.data.install | install-to-string)'
        if ($row.data.search_help | is-not-empty) {
            $command ++= $' --search-help ($row.data.search_help | to nuon)'
        }
        if ($row.data.tags | is-not-empty) {
            $command ++= $' --tags ($row.data.tags | to nuon)'
        }
        if ($row.data.reasons | is-not-empty) {
            $command ++= $' --reasons ($row.data.reasons | to nuon)'
        }
        if ($row.data.links | is-not-empty) {
            $command ++= $' --links ($row.data.links | to nuon)'
        }
        $command
    } |
    append ['    validate-data'] |
    str join " |\n" |
    tee {$in | null} | # NOTE::BUG without this line, an extra newline is inserted into the string
    prepend $func_def |
    append ["}\n"] |
    str join "\n" |
    if not ($in | nu-check --as-module) {
        # have this be first, otherwise $in becomes empty
        $in | save -f $bad_path
        log error $'generated data.nu is not a valid nu module!'

        return (error make {
            'msg': $'generated .nu file is not valid -> ($bad_path)',
        })
    } else {
        # have this be first, otherwise $in becomes empty
        $in | save -f $path
        log info $'saving package data to ($path)'
    }

}

# converts the package install record into a string, handling the closures
export def "install-to-string" [] {
    transpose platform managers |
    update managers {|row|
        $row.managers |
        transpose manager id_or_closure |
        each {|it|
            if ($it.id_or_closure | describe) == 'closure' {
                {'manager': ($it.manager | to nuon), 'id_or_closure': (view source $it.id_or_closure)}
            } else {
                {'manager': ($it.manager | to nuon), 'id_or_closure': ($it.id_or_closure | to nuon)}
            }
        }
    } |
    each {|it|
        $'($it.platform | to nuon): {' ++ (
            $it.managers |
            each {|m|
                $'($m.manager): ($m.id_or_closure)'
            } |
            str join ', '
        ) ++ '}'
    } |
    str join ', ' |
    $'{($in)}'
}

# load the package manager data from the default path
export def "load-data" [] {
    do {
        use package/package_consts.nu ['default_package_data_path']
        use $default_package_data_path ['package-data-load-data']
        package-data-load-data
    }
}

export def "data-diff" [right] {
    let left = ($in)
    let left_packages = ($left | columns)
    let right_packages = ($right | columns)

    let left_only_packages = (
        $left_packages |
        filter {|p|
            $p not-in $right_packages
        }
    )
    let left_packages = (
        $left_packages |
        filter {|p|
            $p not-in $left_only_packages
        }
    )

    let right_only_packages = (
        $right_packages |
        filter {|p|
            $p not-in $left_packages
        }
    )

    let diff_datas = (
        $left_packages |
        filter {|p|
            (
                $left |
                get $p |
                update install {|rec| $rec.install | install-to-string}
            ) != (
                $right |
                get $p |
                update install {|rec| $rec.install | install-to-string}
            )
        }
    )

    let identicals = (
        $left_packages |
        filter {|p| $p not-in $diff_datas}
    )

    {
        'left_only_packages': ($left_only_packages),
        'right_only_packages': ($right_only_packages),
        'identical': ($identicals),
        'data_diverges': ($diff_datas),
    }
}
