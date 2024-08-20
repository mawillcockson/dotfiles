use std [log]

export def main [] {
    # Found with:
    # https://www.gnupg.org/documentation/manuals/gnupg/Listing-options.html
    # https://www.gnupg.org/documentation/manuals/gnupg/Changing-options.html
    # gpgconf --list-options gpg-agent
    echo 'enable-ssh-support:0:1' | gpgconf --change-options gpg-agent

    let chezmoi_config = (
        $env.XDG_CONFIG_HOME |
        path join 'chezmoi' 'chezmoi.toml'
    )
    let git_signing_key = if ($chezmoi_config | path exists) {
        open $chezmoi_config | get data.git_signingKey
    } else {
        log warning 'cannot find chezmoi config filel using old signing key'
        'EDCA9AF7D273FA643F1CE76EA5A7E106D69D1115'
    }
    gpg --keyserver 'hkps://keyserver.ubuntu.com' --receive-key $git_signing_key
    try { gpg-card fetch }

    log info "set my gpg keys as ultimate trust with: gpg --edit-key matthew"
}
