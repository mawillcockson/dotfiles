export use setup/windows/gitconfig.nu
export use setup/windows/windows_terminal.nu
export use setup/windows/fonts.nu
export use setup/windows/clink.nu
export use setup/windows/gpg.nu

export def main [] {
    gitconfig
    windows_terminal
    fonts
    clink
    gpg
}
