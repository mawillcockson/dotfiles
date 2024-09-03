export use setup/linux/fonts.nu
export use setup/linux/system_environment_variables.nu
export use setup/linux/keepass_plugins.nu

export def main [] {
    fonts
    system_environment_variables
    kanata
    keepass_plugins
}

export def kanata [] {
    nu -c 'use package; package install kanata'
}
