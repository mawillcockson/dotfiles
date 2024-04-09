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
export def "save-data" [
    # optional path of where to save the package manager data to
    --path: path,
] {
    transpose platform_name install |
    update install {|row| $row.install | transpose package_manager_name closure | update closure {|row| view source ($row.closure)}} |
    each {|it|
        $'    ($it.platform_name | to nuon): {' | append ($it.install | each {|e|
                $'        ($e.package_manager_name | to nuon): ($e.closure),'
        }) | append '    },'
    } | flatten | prepend [
        `# this file is auto-generated`,
        `# please edit scripts/package/manager.nu instead`,
        ``,
        `# returns the package manager data`,
        `export def "package manager data" [] {{`,
    ] | append `}}` | str join "\n" | save -f ($path | default (
        if ($default_package_manager_data_path | path dirname | path exists) == true {
            $default_package_manager_data_path
        } else {
            mkdir ($default_package_manager_data_path | path dirname)
            $default_package_manager_data_path
        }
    ))
}

# returns the path to the package manager data
export def "data-path" [] {
    $default_package_manager_data_path | (
        if ($in | path exists) == true {
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
