use package/package_consts.nu [platform]

# validates that the input package data has the right shape
export def "validate-data" [] {
    transpose package data |
    each {|row|
        if ('search_help' not-in $row.data) {
            return (error make {
                'msg': $'missing "search_help" from ($row.package | to nuon)',
                'help': 'use the `package data add` command, it will add default values',
            })
        }
        if ($row.data.search_help | is-not-empty) and (($row.data.search_help | describe) != 'list<string>') {
            return (error make {
                'msg': $'for package ($row.package | to nuon) key "search_help" must be list<string>, not ($row.data.search_help | describe)',
                'help': 'use the `package data add` command, it will use the right types',
            })
        }

        if ('tags' not-in $row.data) {
            return (error make {
                'msg': $'missing "tags" from ($row.package | to nuon)',
                'help': 'use the `package data add` command, it will add default values',
            })
        }
        if ($row.data.tags | is-not-empty) and (($row.data.tags | describe) != 'list<string>') {
            return (error make {
                'msg': $'for package ($row.package | to nuon) key "search_help" must be list<string>, not ($row.data.search_help | describe)',
                'help': 'use the `package data add` command, it will use the right types',
            })
        }

        if ('reasons' not-in $row.data) {
            return (error make {
                'msg': $'missing "reasons" from ($row.package | to nuon)',
                'help': 'use the `package data add` command, it will add default values',
            })
        }
        if ($row.data.reasons | is-not-empty) and (($row.data.reasons | describe) != 'list<string>') {
            return (error make {
                'msg': $'for package ($row.package | to nuon) key "search_help" must be list<string>, not ($row.data.search_help | describe)',
                'help': 'use the `package data add` command, it will use the right types',
            })
        }

        if ('links' not-in $row.data) {
            return (error make {
                'msg': $'missing "links" from ($row.package | to nuon)',
                'help': 'use the `package data add` command, it will add default values',
            })
        }
        if ($row.data.links | is-not-empty) and (($row.data.links | describe) != 'list<string>') {
            return (error make {
                'msg': $'for package ($row.package | to nuon) key "search_help" must be list<string>, not ($row.data.search_help | describe)',
                'help': 'use the `package data add` command, it will use the right types',
            })
        }

        if ('install' not-in $row.data) {
            return (error make {
                'msg': $'missing "install" record from ($row.package | to nuon)',
                'help': 'use the `package data add` command, it will require the necessary values',
            })
        }
        let package_managers = (do {
            use package/manager [load-data]
            load-data
        })
        if (
            $package_managers |
            get ([{value: $platform, optional: true}] | into cell-path) |
            is-empty
        ) {
            log warning $'no package managers defined for platform ($platform | to nuon)'
        }
        let all_package_managers = (
            $package_managers |
            values |
            each {|it| $it | columns} |
            flatten |
            compact --empty
        )
        $row.data.install |
        transpose platform managers |
        each {|it|
            if $it.platform not-in ["windows", "mac", "linux", "android"] {
                log warning $'package ($row.package | to nuon) has unusual platform ($it.platform | to nuon)'
            }

            $it.managers |
            transpose manager id_or_closure |
            each {|i|
                if ($i.manager != 'custom') and ($i.manager not-in $all_package_managers) {
                    return (error make {
                        'msg': $'no package manager defined for ($i.manager | to nuon)',
                        'help': $'add a closure for it with `package manager add --save ($i.manager | to nuon) {|| closure that will run the package manager, installing it if necessary/possible}`',
                    })
                }

                if ($i.id_or_closure | describe) not-in ['closure', 'string'] {
                    return (error make {
                        'msg': $'for package ($row.package | to nuon), for manager ($i.manager | to nuon), expected `closure` or `string`, not ($i.id_or_closure | describe)',
                    })
                }
            }
        }

        $row
    } |
    reduce --fold {} {|it,acc| $acc | insert $it.package $it.data}
}
