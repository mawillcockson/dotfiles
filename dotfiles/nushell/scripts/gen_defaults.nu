use consts.nu [default_env, default_config, version_file]

export def main [] {
    let nu_version = (version | get version)

    if (not ($version_file | path exists)) or (open $version_file | $in < $nu_version) {
        print -e "updating generated defaults for new version of nushell"
        config env --default | str replace --all "\r\n" "\n" | save -f $default_env
        config nu --default | str replace --all "\r\n" "\n" | save -f $default_config
        $nu_version | to nuon | save -f $version_file
    }
}
