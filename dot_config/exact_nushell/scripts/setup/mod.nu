use std/log
use consts.nu [platform]
export use setup/windows
export use setup/linux
export use setup/gitconfig.nu
export use setup/gpg.nu
export use setup/fonts.nu

export def main [platform_: string = $platform] {
    gitconfig
    gpg
    fonts
    match $platform_ {
        'windows' => { windows },
        'linux' => { linux },
        _ => {
            log info $"no platform-specific setup for ($platform_ | to nuon) at this time"
        },
    }
}
