const generated = $"($nu.default-config-dir)/scripts/generated"
export const version_file = $"($generated)/version.nuon"

export def main [] {
    let nu_version = (version | get version)

    if (not ($version_file | path exists)) or (open $version_file | $in < $nu_version) {
        print -e "updating generated defaults for new version of nushell"
        config env --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_env.nu"
        config nu --default | str replace --all "\r\n" "\n" | save -f $"($generated)/default_config.nu"
        $nu_version | to nuon | save -f $version_file
    }
}
