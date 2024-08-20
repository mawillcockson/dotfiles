use std [log]
use consts.nu [platform]
export use setup/windows.nu
export use setup/gitconfig.nu
export use setup/gpg.nu

export def main [platform: string = $platform] {
    gitconfig
    gpg
    match $platform {
        'windows' => { windows },
        _ => {
            log info $"no platform-specific setup for ($platform | to nuon) at this time"
        },
    }
}
