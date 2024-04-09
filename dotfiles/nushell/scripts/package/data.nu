# use $'($nu.default-config-dir)/scripts/package/manager.nu'

# add a package to the package metadata file (use `package path` to list it)
export def add [
    name: string,
    install: record,
    --search-help: list<string>,
    --tags: list<string>,
    --reasons: list<string>,
    --links: list<string>,
] {
    # `default` here will absorb the piped input and return that instead of the
    # empty structure
    let packages = default {'customs': {}, 'data': {}}
    # the intended structure is something like
    # {
    #     'customs': {
    #         'platform_name1': {
    #             'package_name1': {|| print 'install package_name1 on platform_name1'},
    #         },
    #         'platform_name2': {
    #             'package_name1': {|| print 'install package_name1 on platform_name2'},
    #         },
    #     },
    #     'data': {
    #         'package_name1': {
    #             'install': {
    #                 'platform_name1': {
    #                     'custom': `{|| print 'install package_name1 on platform_name1'}`,
    #                 },
    #                 'platform_name2': {
    #                     'custom': `{|| print 'install package_name1 on platform_name2'}`,
    #                 },
    #             },
    #         },
    #     },
    # }

    let platform = $nu.os-info.name

    let install_data = (
        $install
        | transpose platform install
        | update install {|row| $row.install | transpose package_manager_name package_id}
        | flatten --all
        # | each {|it|
        #     if $it.package_manager_name == 'custom' {
        #         $it | update package_id {|row|

        #             view source ($row.package_id)
        #         }
        #     } else {
        #         $it
        #     }
        # }
    )
    mut customs = $packages.customs
    let custom_rows = $install_data | where package_manager_name == 'custom'
    for $row in $custom_rows {
        $customs = ($customs | insert ([$row.platform, $name] | into cell-path) {|r| $row.package_id})
    }
    ($install_data
    | where package_manager_name != 'custom'
    | filter {|it|
        let cell_path_table = [['value', 'optional']; [$it.platform, false] [$it.package_manager_name, true]]
        $env.PACKAGE_MANAGER_DATA | get ($cell_path_table | into cell-path) | is-empty
    }
    | each {|it| log error $'package manager ($it.package_manager_name | to nuon) not registered for platform ($it.platform | to nuon)'}
    | each {|it| return (error make {'msg': '1 or more package managers were not registered with the appropriate platform'})}
    )
    let modified = (
        $install_data
        | each {|it|
            if $it.package_manager_name == 'custom' {
                $it | update package_id {|row| view source $row.package_id}
            } else {
                $it
            }
        } | group-by --to-table platform
        | rename platform install
        | update install {|row| $row.install | reject platform | transpose --as-record --header-row}
        | transpose --as-record --header-row
    )
    let package_data = ({
        'install': $modified, 
        'search_help': ($search_help | default []),
        'tags': ($tags | default []),
        'reasons': ($reasons | default []),
        'links': ($links | default []),
    })
    {'customs': ($customs), 'data': ($packages.data | insert $name $package_data)}
}

# returns the path of the main package data file
export def "data-path" [] {
    # this function is here because I don't want to shadow `path` in the
    # data.nu module
    (
        scope variables
        | where name == '$default_package_data_path'
        | get value?
        | compact --empty
        | default [] # sometimes the value returned by `get` is an empty list, and not `null`
        | append $'($nu.default-config-dir)/scripts/generated/package/data.nuon'
        | first
        | if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

# returns the path of the custom package install commands file
export def "customs-data-path" [] {
    # this function is here because I'm not sure where else to put it
    (
        scope variables
        | where name == '$default_package_customs_path'
        | get value?
        | compact --empty
        | default [] # sometimes the value returned by `get` is an empty list, and not `null`
        | append $'($nu.default-config-dir)/scripts/generated/package/customs.nu'
        | first
        | if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

# saves package data, optionally to a specified path
# if no data is provided, it automatically uses `package data generate`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package data to
    --data-path: path,
    # optional path of where to save the customs data to
    --customs-path: path,
] {
    let data = default (generate)
    $data.customs | transpose platform_name install |
    update install {|row| $row.install | transpose package_name closure | update closure {|row| view source ($row.closure)}} |
    each {|it|
        $'    ($it.platform_name | to nuon): {' | append ($it.install | each {|e|
                $'        ($e.package_name | to nuon): ($e.closure),'
        }) | append '    },'
    } | flatten | prepend [
        `# this file is auto-generated`,
        `# please edit scripts/package/data.nu instead`,
        ``,
        `# load data into environment variable`,
        `export-env { $env.PACKAGE_CUSTOMS_DATA = (main) }`,
        ``,
        `# returns the customs data`,
        `export def main [] {$env | get PACKAGE_CUSTOMS_DATA? | default {`,
    ] | append [
        `}}`,
    ] | str join "\n" | save -f ($customs_path | default (
        if ((customs-data-path) | path dirname | path exists) == true {
            (customs-data-path)
        } else {
            mkdir ((customs-data-path) | path dirname)
            (customs-data-path)
        }
    ))
    $data.data | to nuon --indent 4 | save -f ($data_path | default (
        if ((data-path) | path dirname | path exists) == true {
            (data-path)
        } else {
            mkdir ((data-path) | path dirname)
            (data-path)
        }
    ))
    if not (nu-check ($customs_path | default (customs-data-path))) {
        use std [log]
        log error $'generated customs.nu is not valid!'
        return (error make {
            'msg': $'generated .nu file is not valid -> ($customs_path | default (customs-data-path))',
        })
    }
    {'PACKAGE_DATA': ($data.data), 'PACKAGE_CUSTOMS_DATA': ($data.customs)}
}

# reads package data, optionally from specified file
export def main [
    # optional path to read package data from (defaults to `package data data-path`)
    --path: path,
] {
    open --raw ($path | default (data-path)) | from nuon
}

# function to modify to add package data
export def generate [] {
    add 'aria2' {'windows': {'scoop': 'aria2'}} --tags ['scoop'] --reasons ['helps scoop download stuff better'] |
    add 'clink' {'windows': {'scoop': 'clink'}} --tags ['essential'] --reasons ["makes Windows' CMD easier to use", "enables starship in CMD"] |
    add 'git' {'windows': {'scoop': 'git'}} --tags ['essential'] --reasons ['revision control and source management', 'downloading programs'] --links ['https://git-scm.com/docs'] |
    add 'example1' {'platform1': {'custom': {|| print 'installing example1 to platform1'}}, 'platform2': {'custom': {|| print 'installing example1 to platform2'}}} |
    add 'example2' {'platform1': {'custom': {|| print 'installing example2 to platform1'}}, 'platform3': {'custom': {|| print 'installing example2 to platform3'}}}
}
