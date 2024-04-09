# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use manager.nu

export def path [] {
    $nu.default-config-dir | path join 'scripts' 'package' 'data.nuon'
}

# function to modify to add package data
export def "generate-data" [] {
    package add 'git' {'windows': {'scoop': 'git'}} --tags ['essential'] --reasons ['revision control and source management', 'downloading programs'] --links ['https://git-scm.com/docs']
}
