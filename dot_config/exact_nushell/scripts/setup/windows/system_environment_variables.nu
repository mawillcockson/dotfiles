use std/log
use utils.nu ["powershell-safe"]

export def default_variables [] {
    let home = (
        $env |
        get HOME? USERPROFILE? |
        append ('~' | path expand) |
        append ($nu | get home-path? home-dir?) |
        compact --empty |
        where {path exists} |
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
        where {|it| $it | path exists} |
        compact --empty |
        first
    }

    let xdg_data_home = if ('XDG_DATA_HOME' in $env) {
        $env.XDG_DATA_HOME
    } else {
        let chezmoi_config = if (which chezmoi | is-not-empty) {
            chezmoi dump-config --format=json |
            from json
        } else {null}
        [
            $chezmoi_config.env?.XDG_DATA_HOME?,
            (if ($chezmoi_config.destDir? | is-not-empty) {$chezmoi_config.destDir | path join '.local' 'share'} else {null}),
            ($home | path join '.local' 'share'),
        ] |
        where {path exists} |
        compact --empty |
        first
    }

    return {
        # NOTE::DEPRECATION v0.98.0
        # https://www.nushell.sh/blog/2024-09-17-nushell_0_98_0.html#ir-is-now-the-default-evaluator-toc
        'NU_USE_IR': '1',
        'XDG_CONFIG_HOME': $xdg_config_home,
        'XDG_DATA_HOME': $xdg_data_home,
    }
}

export def main [
    variables?: record
] {
    let variables = (
        $variables |
        default (default_variables)
    )

    $variables |
    transpose name value |
    to json |
    powershell-safe -c '$Input | ConvertFrom-Json | ForEach-Object { [Environment]::SetEnvironmentVariable($_.name, $_.value, "User") }'

}
