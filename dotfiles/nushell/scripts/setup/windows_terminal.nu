use std [log]

const platform = ($nu.os-info.name)
const pwsh_guid = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
const cmd_guid = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}"
const font_name = "DejaVuSansM Nerd Font"
const urls = {
    latte: 'https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/latte.json',
    latte_theme: 'https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/latteTheme.json',
    mocha: 'https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/mocha.json',
    mocha_theme: 'https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/mochaTheme.json',
}

# install windows terminal
export def install [] {
    match $platform {
        'windows' => {
            log info 'installing Windows Terminal on Windows'
            (
                ^winget install
                    --accept-source-agreements
                    --accept-package-agreements
                    '9N0DX20HK701' # Microsoft.WindowsTerminal msstore app ID
            )
        },
        _ => {
            return (error make {
                'msg': $'platform not yet supported: ($platform | to nuon)'
            })
        },
    }
}

export def "configure whole-file" [] {
    let terminal_settings_file = (
        $env.LOCALAPPDATA
        | path join 'Packages' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState' 'settings.json'
    )
    log info $'reading current settings from: ($terminal_settings_file)'
    let original_contents = (open $terminal_settings_file)

    let backup_dir = (
        [
            ('~/projects/dotfiles/dotfiles' | path expand),
        ]
        | append (
            $env
            | get USERPROFILE? UserProfile?
            | default ([('~' | path expand)])
        )
        | filter {|it| $it | path exists}
        | first
        | path join 'windows_terminal'
    )
    log info $'creating backup dir at ($backup_dir)'
    mkdir $backup_dir
    mut backup_name = $'($env.COMPUTERNAME)_settings.json'
    let existing_backups = do {
        cd $backup_dir
        glob --no-dir --no-symlink '*settings.json'
    }
    if not ($existing_backups | any {|it| (open $it) == $original_contents}) {
        mut i = 0
        while ($backup_dir | path join $backup_name | path exists) {
            $i += 1
            $backup_name = $'($env.COMPUTERNAME)-($i)_settings.json'
        }
        log info $'new file found, writing to ($backup_name)'
        $original_contents | save ($backup_dir | path join $backup_name)
    } else {
        log info 'settings.json is not new'
    }

    log info 'modifying and writing out changes'

    # Take the profiles list, and modify each item that has a guid that is
    # either the PowerShell or CMD GUID to indicate the font face. Then, set
    # the default profile to PowerShell. Write out to original file.
    (
        $original_contents
        | update profiles.list {|obj|
            $obj.profiles.list | each {|it|
                if ($it.guid in [$pwsh_guid, $cmd_guid]) {
                    $it | upsert font {'face': ($font_name)}
                } else {
                    $it
                }
            }
        }
        | update defaultProfile ($pwsh_guid)
        | save -f $terminal_settings_file
    )
}

export def "configure fragments" [] {
    # https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions
    let fragments_dir = (
        $env.LOCALAPPDATA
        | path join 'Microsoft' 'Windows Terminal' 'Fragments'
    )
    let program = 'catppuccin'
    mkdir ($fragments_dir | path join $program)

    log info 'getting catppuccin themes'
    let catppuccin = (
        $urls
        | transpose
        | rename name data
        | update data {|row| http get --max-time 3 $row.data }
        | transpose --as-record --header-row
    )
    log info $'constructing fragment and writing to ($fragments_dir | path join $program)'
    {
        'profiles': [
            {
                'updates': ($pwsh_guid),
                'colorScheme': {
                    'light': ($catppuccin.latte.name),
                    'dark': ($catppuccin.mocha.name),
                },
                'font': {
                    'face': ($font_name),
                },
            },
            {
                'updates': ($cmd_guid),
                'colorScheme': {
                    'light': ($catppuccin.latte.name),
                    'dark': ($catppuccin.mocha.name),
                },
                'font': {
                    'face': ($font_name),
                },
            },
        ],
        'schemes': [($catppuccin.latte), ($catppuccin.mocha)],
        'themes': [($catppuccin.latte_theme), ($catppuccin.mocha_theme)],
    } | to json --tabs 1 | save -f ($fragments_dir | path join $program 'profile_updates.json')
}
