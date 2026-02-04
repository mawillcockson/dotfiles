export def main []: [nothing -> nothing] {
	use std/log

	let systemd_tmpfiles_user_config = (
		$env.XDG_CONFIG_HOME? |
		default (chezmoi dump-config --format=json | from json | get env.XDG_CONFIG_HOME) |
		path join 'user-tmpfiles.d' 'user-downloads.conf'
	)
	
	if ($systemd_tmpfiles_user_config | path exists) {
		log debug 'chezmoi has already been run, and configuration is in place'
	} else {
		log info 'using chezmoi to put configuration file into place'
		chezmoi apply --refresh-externals=never $systemd_tmpfiles_user_config
	}
	log info 'enabling and starting user systemd-tmpfiles-clean.timer, to automatically delete old files in ~/Downloads every once in a while'
	systemctl --user daemon-reload
	systemctl --user enable systemd-tmpfiles-clean.timer
	try {
		systemctl --user start systemd-tmpfiles-clean.timer
		log info 'started cleaning timer (and it probably already ran)'
	} catch {
		log warning 'problem starting systemd-tmpfiles-clean.timer, may need to log out and in again'
	}
}
