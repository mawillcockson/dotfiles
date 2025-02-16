const version_value = (version)
export const version_info = {
    version: ($version_value.version),
    major: ($version_value.major),
    minor: ($version_value.minor),
    patch: ($version_value.patch),
}
export const platform = ($nu.os-info.name)
export const scripts = ($nu.default-config-dir | path join 'scripts')
export const autoload = ($nu.default-config-dir | path join 'autoload')
export const generated = ($scripts | path join 'generated')

# std/log
export const nu_log_date_format = '%Y-%m-%dT%H:%M:%S%.3f'
export const nu_log_format = '%ANSI_START%%DATE% [%LEVEL%]%ANSI_STOP% - %MSG%%ANSI_STOP%'

# package
export const default_package_path = ($generated | path join 'package')
export const default_package_manager_data_path = ($default_package_path | path join 'managers.nu')
export const default_package_data_path = ($default_package_path | path join 'data.nu')
