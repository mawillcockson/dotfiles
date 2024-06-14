const generated = $'($nu.default-config-dir)/scripts/generated'
const default_package_path = $'($generated)/package'
export const default_package_data_path = $'($default_package_path)/data.nu'
export const default_package_manager_data_path = $'($default_package_path)/managers.nu'
export const platform = ($nu.os-info.name)
