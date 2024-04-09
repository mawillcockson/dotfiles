# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use manager.nu

export def "data-path" [] {
    $default_package_data_path | (
        if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

# function to modify to add package data
export def "generate-data" [] {
    package add 'git' {'windows': {'scoop': 'git'}} --tags ['essential'] --reasons ['revision control and source management', 'downloading programs'] --links ['https://git-scm.com/docs']
}
