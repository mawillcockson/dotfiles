export const platform = ($nu.os-info.name)
export const preconfig = $'($nu.default-config-dir)/preconfig.nu'
export const scripts = $'($nu.default-config-dir)/scripts'
export const generated = $'($scripts)/generated'
export const postconfig = $'($generated)/postconfig.nu'
export const version_file = $'($generated)/version.nuon'

export const default_env = $"($generated)/default_env.nu"
export const default_config = $"($generated)/default_config.nu"

# package
export const default_package_path = $'($generated)/package'
export const default_package_manager_data_path = $'($default_package_path)/managers.nu'
export const default_package_data_path = $'($default_package_path)/data.nuon'
#export const default_package_customs_path = $'($default_package_path)/customs.nu'
