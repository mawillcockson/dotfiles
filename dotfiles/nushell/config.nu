const scripts = $"($nu.default-config-dir)/scripts"
const generated = $"($scripts)/generated"
const default_config = $"($generated)/default_config.nu"
source $default_config

const postconfig = $"($generated)/postconfig.nu"
# because this is a parser directive, it can't be guarded with `if path
# exists`: if it exists, it'll be sourced, and if it doesn't, the whole file
# can't be read
source $postconfig

overlay use clipboard.nu
overlay use utils.nu

# package module
overlay use --prefix --reload package
overlay use --prefix --reload $default_package_manager_data_path as 'package manager data'
overlay use --prefix --reload $default_package_data_path as 'package data'
overlay use --prefix --reload $default_package_customs_path as 'package customs data'

alias dt = date my-format

# Atuin should be able to handle a lot of history, so don't cull based on
# number of entries
# let opopo = {
#     history.max_size: 10_000_000
#     show_banner: false
# }
