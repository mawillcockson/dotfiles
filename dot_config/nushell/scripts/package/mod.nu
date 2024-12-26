# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use package/manager
export use package/data
export use package/data [add]
export use package/search.nu
export use package/collect.nu
export use package/install.nu
export use package/check.nu

export def "path" [] {
    use package/package_consts.nu [default_package_data_path, default_package_manager_data_path]
    {
        'data': $default_package_data_path,
        'manager': $default_package_manager_data_path,
        'managers': $default_package_manager_data_path,
    }
}
