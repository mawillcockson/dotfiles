const version_value = (version)
export const version_info = {
    version: ($version_value.version),
    major: ($version_value.major),
    minor: ($version_value.minor),
    patch: ($version_value.patch),
}
export const platform = ($nu.os-info.name)
export const preconfig = $'($nu.default-config-dir)/preconfig.nu'
export const scripts = $'($nu.default-config-dir)/scripts'
export const generated = $'($scripts)/generated'
export const postconfig = $'($generated)/postconfig.nu'
export const version_file = $'($generated)/version.nuon'

export const default_env = $'($generated)/default_env.nu'
export const default_config = $'($generated)/default_config.nu'

# std/log
export const nu_log_date_format = '%Y-%m-%dT%H:%M:%S%.3f'
export const nu_log_format = '%ANSI_START%%DATE% [%LEVEL%]%ANSI_STOP% - %MSG%%ANSI_STOP%'

# package
export const default_package_path = $'($generated)/package'
export const default_package_manager_data_path = $'($default_package_path)/managers.nu'
export const default_package_data_path = $'($default_package_path)/data.nu'
#export const default_package_customs_path = $'($default_package_path)/customs.nu'
