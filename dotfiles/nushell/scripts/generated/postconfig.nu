# the contents of this file are auto-generated in preconfig.nu, and should not be edited by hand

const default_config_dir = $nu.default-config-dir
const scripts = $"($default_config_dir)/scripts"
const generated = $"($scripts)/generated"
source $"($generated)/atuin.nu"
overlay use $"($generated)/starship.nu"