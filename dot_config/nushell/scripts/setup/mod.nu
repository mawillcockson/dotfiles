use consts.nu [platform]
export use setup/windows.nu

export def main [platform: string = $platform] {
    match $platform {
        'windows' => { windows },
        _ => { return (error make {
            'msg': $'platform not yet implemented -> ($platform | to nuon)',
            })
        },
    }
}
