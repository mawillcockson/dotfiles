# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use manager.nu
export use data.nu

# returns the path of the main package data file
export def "data path" [] {
    # this function is here because I don't want to shadow `path` in the
    # data.nu module
    $default_package_data_path | (
        if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

