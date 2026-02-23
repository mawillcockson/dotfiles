use std/log
export use setup/windows/gitconfig.nu
export use setup/windows/windows_terminal.nu
export use setup/windows/fonts.nu
export use setup/windows/clink.nu
export use setup/windows/gpg.nu

export def main [
	--skip-fonts, # whether to run the fonts module or not
]: [nothing -> nothing] {
    if not $skip_fonts {
        fonts
    }

    gitconfig
    windows_terminal
    clink
    gpg
    kanata
}

export def kanata [] {
    nu -c 'use package; package install kanata'
    log info 'may need to restart shell so that kanata is in $PATH, and run "chezmoi apply" again, to move files into the right places'
}
