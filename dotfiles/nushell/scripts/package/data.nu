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

# function to modify to add package data
export def generate [] {
    add 'aria2' {'windows': {'scoop': 'aria2'}} --tags ['scoop'] --reasons ['helps scoop download stuff better'] |
    add 'clink' {'windows': {'scoop': 'clink'}} --tags ['essential'] --reasons ["makes Windows' CMD easier to use", "enables starship in CMD"] |
    add 'git' {'windows': {'scoop': 'git'}} --tags ['essential'] --reasons ['revision control and source management', 'downloading programs'] --links ['https://git-scm.com/docs']
}
