# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use manager
export use data
export use data [add]
export use search.nu
export use collect.nu
export use install.nu

export def "path" [] {
    use consts.nu [default_package_data_path, default_package_manager_data_path]
    {
        'data': $default_package_data_path,
        'manager': $default_package_manager_data_path,
        'managers': $default_package_manager_data_path,
    }
}
