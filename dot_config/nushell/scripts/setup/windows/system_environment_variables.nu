use std [log]
use utils.nu ["powershell-safe"]

export def default_variables [] {
    let home = (
        $env |
        get HOME? USERPROFILE? |
        append [
            ('~' | path expand),
            ($nu.home-path),
        ] |
        compact --empty |
        filter {|it| $it | path exists} |
        first
    )

    let xdg_config_home = if ('XDG_CONFIG_HOME' in $env) {
        $env |
        get XDG_CONFIG_HOME
    } else {
        let chezmoi_config = if (which chezmoi | is-not-empty) {
            chezmoi dump-config --format=json |
            from json
        } else {null}
        [
            $chezmoi_config.env?.XDG_CONFIG_HOME?,
            (if ($chezmoi_config.destDir? | is-not-empty) {$chezmoi_config.destDir | path join '.config'} else {null}),
            ($home | path join '.config'),
        ] |
        filter {|it| $it | path exists} |
        compact --empty |
        first
    }

    return {
        'NU_USE_IR': '1',
        'XDG_CONFIG_HOME': $xdg_config_home,
    }
}

export def main [
    variables?: list<string>
] {
    let variables = (
        $variables |
        default (default_variables)
    )

    $variables |
    transpose name value
    to json |
    powershell-safe -c '$Input | ConvertFrom-Json | ForEach-Object { [Environment]::SetEnvironmentVariable($_.name, $_.value, "User") }'

}
