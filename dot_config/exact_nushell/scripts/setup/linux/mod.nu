export use setup/linux/fonts.nu
export use setup/linux/system_environment_variables.nu
export use setup/linux/keepass_plugins.nu
export use setup/linux/tmux.nu
export use setup/linux/clean_downloads.nu

export def main [
	--skip-fonts, # whether to run the fonts module or not
	--setup-downloads-cleaning, # whether to unconditionally setup downloads cleaning
]: [nothing -> nothing] {
    use std/log

	if not $skip_fonts {
		fonts
	}
    system_environment_variables
    kanata
    keepass_plugins
    tmux
	if ($setup_downloads_cleaning) {
		clean_downloads
	} else if ($nu.is-interactive) {
		if ([yes no] | input list --fuzzy 'enable periodic removal of old downloads?') == 'yes' {
			clean_downloads
		}
	} else {
		log info 'shell is not interactive; to enable periodic removal of old downloads, run:
nu -c "use setup; setup linux clean_downloads"'
	}
}

export def kanata [] {
    run-external $nu.current-exe '-c' 'use package; package install kanata'
}
