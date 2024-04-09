const default_env = $"($nu.default-config-dir)/scripts/generated/default_env.nu"
source $default_env

const default_package_manager_data_path = $'($nu.default-config-dir)/scripts/generated/package/managers.nu'
const default_package_data_path = $'($nu.default-config-dir)/scripts/generated/package/data.nuon'
const default_package_customs_path = $'($nu.default-config-dir)/scripts/generated/package/customs.nu'
[
    $default_package_manager_data_path,
    $default_package_data_path,
    $default_package_customs_path,
] | each {|it|
    if not ($it | path exists) {
        mkdir ($it | path dirname)
        touch $it
    } else if ($it | str ends-with '.nu') and (not (nu-check $it)) {
        use std [log]
        log error $'not a valid .nu file! -> ($it)'
        log warning 'truncating it'
        echo '' | save -f $it
    }
}

# generate stuff that can then be sourced in config.nu
let preconfig = $nu.default-config-dir | path join "preconfig.nu"
if ($preconfig | path exists) {
    nu $preconfig
}
