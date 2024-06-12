use setup/windows_terminal.nu

export def main [] {
    windows_terminal
    nu -c ($nu.default-config-dir | path join 'scripts' 'link.nu')
}
