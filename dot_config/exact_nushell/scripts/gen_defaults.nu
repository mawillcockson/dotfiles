use consts.nu [default_env, default_config, version_file]
use startup_utils.nu [nu-version]
use std/log

export def main [] {
    if ($version_file | path exists) {
        let contents = (open $version_file)
        if ($contents | describe) == 'record<major: int, minor: int, patch: int>' {
            if (nu-version '<=' $contents) {
                log debug $'version file "($version_file)" is the same version as the current running nushell, or is newer'
                return null
            }

            if (nu-version '>=' {major: 0, minor: 101, patch: 0}) {
                log debug (
                    "from nushell v0.101.0 onwards, the $env.config variable is no longer empty by default, and including the defaults in the user config is discouraged:\n"
                    + 'https://www.nushell.sh/blog/2024-12-04-configuration_preview.html'
                )
                return null
            }
        }
    }

    print -e "updating generated defaults for new version of nushell"
    config env --default | str replace --all "\r\n" "\n" | save -f $default_env
    config nu --default | str replace --all "\r\n" "\n" | save -f $default_config
    version | select major minor patch | to nuon | save -f $version_file
}
