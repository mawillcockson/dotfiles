use consts.nu [platform]
use std [log]

const pwsh_guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'
const cmd_guid = '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}'
const font_name = {
    'term': 'DejaVuSansM Nerd Font',
    'text': 'ComicCode Nerd Font',
}
const themes_program = 'catppuccin'
const profiles_program = 'mawillcockson'
const nvim_profile_filename = 'neovim.json'
const open_quake_profile_filename = 'open_quake.json'

export def "get-catppuccin" [] {
    get dotfiles-dir |
    path join 'catppuccin' |
    do {
        cd $in
        glob --no-dir --no-symlink --depth 1 'windows_terminal_*.json'
    } |
    each {|it|
        let name = (
            $it |
            path basename |
            str replace --regex '^.*windows_terminal_(?P<name>.*?)\.json$' '$name'
        )
        {($name): (open $it)}
    } |
    reduce {|it,acc| $acc | merge $it}
}

# return the path to my dotfiles
export def "get dotfiles-dir" [] {
    ^chezmoi dump-config --format=json |
    from json |
    get 'workingTree' |
    path expand --strict
}

# return the path to the directory where profile fragments can be placed
export def "get fragments-dir" [] {
    match ($platform) {
        'windows' => { $env.LOCALAPPDATA | path join 'Microsoft' 'Windows Terminal' 'Fragments' },
        _ => { return (error make {'msg': $'platform not yet supported: ($platform)'})},
    }
}

# return path to terminal's settings.json
export def "get terminal-settings-file" [] {
    match ($platform) {
        'windows' => {
            $env.LOCALAPPDATA |
            path join 'Packages' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState' 'settings.json'
        },
        _ => { return (error make {'msg': $'platform not yet supported: ($platform)'})},
    }
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

export def "get-computername" [] {
    let env_var = (
        $env |
        get COMPUTERNAME?
    )
    if ($env_var | is-not-empty) {
        return $env_var
    }

    let host = try {^hostname | str trim}
    if ($host | is-not-empty) {
        return $host
    }

    return (random uuid)
}

export def "configure whole-file" [--start-on-login] {
    let terminal_settings_file = (get terminal-settings-file)
    log info $'reading current settings from: ($terminal_settings_file)'
    let original_contents = (open $terminal_settings_file)

    let backup_dir = (
        get dotfiles-dir |
        path join 'windows_terminal'
    )
    log info $'creating backup dir at ($backup_dir)'
    mkdir $backup_dir
    mut backup_name = $'(get-computername)_settings.json'
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

    let nvim_profile = (get fragments-dir | path join $profiles_program $nvim_profile_filename)
    let open_quake_profile = (get fragments-dir | path join $profiles_program $open_quake_profile_filename)
    let open_quake_quid = (
        ^python
            (get dotfiles-dir | path join 'windows_terminal' 'profile_guid.py')
            'fragment'
            $profiles_program
            (open $open_quake_profile | get profiles.0.name)
        | str trim
    )

    let pwsh_profile = (
        $original_contents
        | get profiles.list
        | filter {|it| $pwsh_guid == ($it | get guid?)}
        | if ($in | is-empty) { {} } else { $in | first }
        | upsert name 'Windows PowerShell'
        | upsert commandline 'powershell.exe'
        | upsert font {'face': ($font_name.term)}
    )
    let cmd_profile = (
        $original_contents
        | get profiles.list
        | filter {|it| $cmd_guid == ($it | get guid?)}
        | if ($in | is-empty) { {} } else { $in | first }
        | upsert name 'Command Prompt'
        | upsert commandline 'cmd.exe'
        | upsert font {'face': ($font_name.term)}
    )
    let profiles_list = (
        $original_contents
        | get profiles.list
        | filter {|it| $it | get guid? | ($in not-in [($pwsh_guid), ($cmd_guid)])}
        | prepend [($pwsh_profile), ($cmd_profile)]
    )

    let terminal_screenshots_dir = (
        $env
        | get OneDrive? ONEDRIVE? OneDriveConsumer? ONEDRIVECONSUMER?
        | first
        | default ('~/OneDrive' | path expand)
        | path join 'Pictures' 'Screenshots' 'Windows Terminal'
    )
    mkdir $terminal_screenshots_dir

    log info 'modifying and writing out changes'

    (
        $original_contents
        | update profiles.list ($profiles_list)
        | update defaultProfile {|rec|
            if ($nvim_profile | path exists) {
                (
                    ^python
                        (get dotfiles-dir | path join 'windows_terminal' 'profile_guid.py')
                        'fragment'
                        $profiles_program
                        (open $nvim_profile | get profiles.0.name)
                    | str trim
                )
            } else {
                $pwsh_guid
            }
        }
        | upsert startOnUserLogin $start_on_login
        | upsert windowingBehavior 'useExisting'
        | upsert launchMode 'default'
        | upsert disableProfileSources ['Windows.Terminal.Azure']
        | upsert startupActions $'--profile=($open_quake_quid)'
        | upsert compatibility.allowHeadless true
        | upsert minimizeToNotificationArea true
        | upsert multiLinePasteWarning false
        | upsert lang 'en-US'
        | upsert theme 'system'
        | upsert alwaysShowTabs false
        | upsert showTabsInTitlebar true
        | upsert useAcrylicInTabRow false
        | upsert disableAnimations true
        | upsert actions [
            { 'command': null, 'keys': 'alt+f4' },
            { 'command': null, 'keys': 'ctrl+shift+f' },
            { 'command': null, 'keys': 'ctrl+shift+space' },
            { 'command': null, 'keys': 'ctrl+,' },
            { 'command': null, 'keys': 'ctrl+shift+,' },
            { 'command': null, 'keys': 'ctrl+alt+,' },
            { 'command': null, 'keys': 'alt+space' },
            { 'command': null, 'keys': 'alt+enter' },
            { 'command': null, 'keys': 'ctrl+shift+d' },
            { 'command': null, 'keys': 'ctrl+shift+t' },
            { 'command': null, 'keys': 'ctrl+tab' },
            { 'command': null, 'keys': 'ctrl+shift+tab' },
            { 'command': null, 'keys': 'ctrl+shift+n' },
            { 'command': null, 'keys': 'alt+shift+d' },
            { 'command': null, 'keys': 'alt+shift+-' },
            { 'command': null, 'keys': 'alt+shift+plus' },
            { 'command': null, 'keys': 'ctrl+shift+w' },
            { 'command': null, 'keys': 'alt+down' },
            { 'command': null, 'keys': 'alt+left' },
            { 'command': null, 'keys': 'alt+right' },
            { 'command': null, 'keys': 'alt+up' },
            { 'command': null, 'keys': 'ctrl+alt+left' },
            { 'command': null, 'keys': 'alt+shift+down' },
            { 'command': null, 'keys': 'alt+shift+left' },
            { 'command': null, 'keys': 'alt+shift+right' },
            { 'command': null, 'keys': 'alt+shift+up' },
            { 'command': null, 'keys': 'ctrl+c' },
            { 'command': null, 'keys': 'enter' },
            { 'command': null, 'keys': 'ctrl+v' },
            { 'command': null, 'keys': 'ctrl+shift+v' },
            { 'command': null, 'keys': 'ctrl+shift+a' },
            { 'command': null, 'keys': 'ctrl+shift+m' },
            { 'command': null, 'keys': 'ctrl+shift+up' },
            { 'command': null, 'keys': 'ctrl+shift+down' },
            { 'command': null, 'keys': 'ctrl+shift+pgup' },
            { 'command': null, 'keys': 'ctrl+shift+pgdn' },
            { 'command': null, 'keys': 'ctrl+shift+home' },
            { 'command': null, 'keys': 'ctrl+shift+end' },
            { 'command': 'commandPalette', 'keys': 'ctrl+shift+p', 'name': 'Open command palette' },
            { 'command': 'openNewTabDropdown', 'keys': 'ctrl+alt+n', 'name': 'Open new tab dropdown' },
            { 'command': {'action': 'moveTab', 'direction': 'forward', 'window': 'new'}, 'keys': 'ctrl+alt+shift+n', 'name': 'Move tab to new window' },
            {
                'name': 'Open new tab with powershell and close all other tabs',
                'command': {
                    'action': 'multipleActions',
                    'actions': [
                        {'action': 'newTab', 'profile': ($pwsh_guid)},
                        'closeOtherTabs',
                    ],
                },
                'keys': 'ctrl+alt+shift+m',
            },
            { 'command': 'toggleFullscreen', 'keys': 'f11', 'name': 'Toggle fullscreen' },
            { 'command': {'action': 'copy', 'singleLine': false}, 'keys': 'ctrl+insert', 'name': 'Copy' },
            { 'command': 'paste', 'keys': 'shift+insert', 'name': 'Paste' },
            { 'command': { 'action': 'adjustFontSize', 'delta': 1 }, 'keys': 'ctrl+=' },
            { 'command': { 'action': 'adjustFontSize', 'delta': 1 }, 'keys': 'ctrl+numpad_plus' },
            { 'command': { 'action': 'adjustFontSize', 'delta': -1 }, 'keys': 'ctrl+-' },
            { 'command': { 'action': 'adjustFontSize', 'delta': -1 }, 'keys': 'ctrl+numpad_minus' },
            { 'command': 'resetFontSize', 'keys': 'ctrl+0' },
            { 'command': 'resetFontSize', 'keys': 'ctrl+numpad_0' },
            { 'command': {'action': 'exportBuffer', 'path': ($terminal_screenshots_dir)}, 'keys': 'f12' },
            {
                'command': {
                    'action': 'globalSummon',
                    'desktop': 'toCurrent',
                    'monitor': 'toCurrent',
                    'name': '_quake',
                    'dropdownDuration': 0,
                    'toggleVisbility': true,
                },
                'keys': 'win+`'
            },
        ]
        | upsert profiles.defaults {
            'intenseTextStyle': 'bold',
            'cursorShape': 'bar',
            'useAcrylic': false,
            'antialiasingMode': 'grayscale',
            'altGrAliasing': false,
            'snapOnInput': true,
            'historySize': 32767,
            'bellStyle': 'all',
            'experimental': {'useAtlasEngine': true},
        }
        | save -f $terminal_settings_file
    )
    # NOTE: Consider adding these
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#unbind-keys-disable-keybindings
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#adjust-font-size
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#reset-font-size
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#export-buffer
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/actions#global-summon
    # - https://learn.microsoft.com/en-us/windows/terminal/command-palette#iterable-commands
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-general
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-general#hide-profile-from-dropdown
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/themes#application-theme
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/startup#disable-dynamic-profiles
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/startup#startup-actions
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/interaction#minimize-to-notification-area
    # - https://learn.microsoft.com/en-us/windows/terminal/customize-settings/interaction#always-show-notification-icon
    # Check out these:
    # - https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalSettingsModel/userDefaults.json
    # - https://github.com/microsoft/terminal/blob/main/src/cascadia/TerminalSettingsModel/defaults.json
}

export def "configure fragments" [
    # check for new versions of themes
    --no-check
] {
    # https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions
    let fragments_dir = (get fragments-dir)
    let themes_dir = ($fragments_dir | path join $themes_program)
    mkdir $themes_dir

    let catppuccin = (get-catppuccin)
    log info $'constructing ($themes_program) fragment and writing to ($themes_dir)'
    {
        'schemes': [($catppuccin.latte), ($catppuccin.mocha)],
        'themes': [($catppuccin.latte_theme), ($catppuccin.mocha_theme)],
    } | to json --tabs 1 | save -f ($themes_dir | path join 'themes_and_schemes.json')

    let profiles_dir = ($fragments_dir | path join $profiles_program)
    mkdir $profiles_dir
    log info $'constructing ($profiles_program) fragment and writing to ($profiles_dir)'
    {
        'profiles': [
            {
                'updates': ($pwsh_guid),
                'colorScheme': {
                    'light': ($catppuccin.latte.name),
                    'dark': ($catppuccin.mocha.name),
                },
                'font': {
                    'face': ($font_name.term),
                },
            },
            {
                'updates': ($cmd_guid),
                'colorScheme': {
                    'light': ($catppuccin.latte.name),
                    'dark': ($catppuccin.mocha.name),
                },
                'font': {
                    'face': ($font_name.term),
                },
            },
        ],
    } | to json --tabs 1 | save -f ($profiles_dir | path join 'default_profile_updates.json')

    {
        'profiles': [
            {
                'name': 'open_quake',
                'commandline': 'cmd /d /c "wt --window _quake&&exit"',
                'hidden': true,
            },
        ],
    } | to json --tabs 1 | save -f ($profiles_dir | path join $open_quake_profile_filename)

    if (which 'nvim.exe' | is-not-empty) {
        let nvim_ico = ('~/scoop/apps/neovim/current/share/nvim/runtime/neovim.ico' | path expand)
        {
            'profiles': [
                {
                    'name': 'Neovim',
                    'commandline': 'nvim.exe',
                    'startingDirectory': '%USERPROFILE%',
                    'scrollbarState': 'hidden',
                    'antialiasingMode': 'grayscale', # 'cleartype'
                    'snapOnInput': false,
                    'historySize': 200,
                    'font': {
                        'face': ($font_name.term),
                    },
                    'colorScheme': {
                        'light': ($catppuccin.latte.name),
                        'dark': ($catppuccin.mocha.name),
                    },
                    'icon': ($nvim_ico),
                },
            ],
        } | to json --tabs 1 | save -f ($profiles_dir | path join $nvim_profile_filename)
    }
}

export def main [--start-on-login] {
    if (which wt | is-empty) {
        install
    }

    # the whole-file references elements added by fragments, so that needs to
    # be added first
    configure fragments #--no-check
    configure whole-file --start-on-login=($start_on_login)
}
