const default_env = $"($nu.default-config-dir)/scripts/generated/default_env.nu"
source $default_env

# generate stuff that can then be sourced in config.nu
let preconfig = $nu.default-config-dir | path join "preconfig.nu"
if ($preconfig | path exists) {
    nu $preconfig
}
