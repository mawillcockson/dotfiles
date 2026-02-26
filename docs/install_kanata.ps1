Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$tmpdir = (Join-Path $Env:TEMP "kanata")
$kanata_path = (Join-Path $tmpdir "kanata_path.txt")
$config = (Join-Path $tmpdir "kanata.kbd")

if (-not (Test-Path -LiteralPath $tmpdir)) {
    New-Item -ItemType "directory" -Path $tmpdir
}

if (-not (Test-Path -LiteralPath $kanata_path)) {
    $asset = (irm -useb "https://api.github.com/repos/jtroo/kanata/releases/latest" | Select-Object -ExpandProperty "assets" | Where-Object -Property "name" -Like -Value "*winIOv2*" | Select-Object -First 1 )
    $executable = (Join-Path $tmpdir $asset.name)
    irm -useb -uri $asset.browser_download_url -outfile $executable
    New-Item -ItemType "file" -Path $tmpdir -Name "kanata_path.txt" -Force
    Out-File -LiteralPath $kanata_path -InputObject $executable -Encoding "utf8" -Force
}

if (-not (Test-Path -LiteralPath $config)) {
    irm -useb "https://github.com/mawillcockson/dotfiles/raw/main/dot_config/kanata/kanata.kbd" -outfile $config
}

& "$(Get-Content -Encoding UTF8 -LiteralPath $kanata_path)" --cfg $config

---

export const kanata_config_url = 'https://github.com/mawillcockson/dotfiles/raw/refs/heads/main/dot_config/kanata/kanata.kbd'
export const github_latest_release_url = 'https://api.github.com/repos/jtroo/kanata/releases/latest'

export def "download exe" [
    # location to write executable to
    output: path,
    # whether to force a redownload
    --force,
]: [nothing -> nothing] {
    let redownload = (
        if ($output | path exists) {
            log info $'kanata already downloaded to: ($output)'
            log info 'trying to check version'
            let result = (
                do {$output --version} | complete
            )
            if $result.exit_code == 0 {
                log info 'kanata --version worked, all done downloading'
                return
            }
            log warning 'issue checking version, redownloading'
            true
        } else {false}
    ) or $force

    # NOTE::DEPRECATED v0.110.0 $nu.temp-path -> $nu.temp-dir
    let tmpdir = (
        $nu |
        get temp-path? temp-dir? |
        compact --empty |
        first
    )
    log info $'using as tmpdir: ($tmpdir | to nuon)'
    let today = (date now | formate date '%Y-%m-%d')

    let tmp_json = (
        $tmpdir |
        path join $'kanata_latest_($today).json'
    )
    if $redownload or (not ($tmp_json | path exists)) {
        log info $'downloading latest kanata release info to: ($tmp_json | to nuon)'
        http get --redirect-mode follow $github_latest_release_url |
        save -f $tmp_json
    }

    let archive_file = (
        $tmpdir |
        path join $'kanata_($platform)_($today).zip'
    )
    if $redownload or (not ($archive_file | path exists)) {
        let download_url = (
            open $tmp_json |
            get assets |
            where name has $platform and name has 'x64' |
            get browser_download_url |
            first
        )
        log info $'downloading latest release archive from: ($download_url)'
        log info $'downloading to: ($archive_file | to nuon)'
        http get --redirect-mode follow $download_url |
        save -f $archive_file
    }

    if (not $redownload) or ($output | path exists) {
        log info $'executable already exists at ($output)'
        return null
    }

    let archive_unpack_dir = $tmpdir | path join 'kanata_archive_unpack'
    log info $'unpacking archive to: ($output)'
    mkdir $archive_unpack_dir
    if (which 7z | is-empty) and $platform == 'windows' {
        log warning 'missing 7z, using builtin Expand-Archive'
        use utils.nu ["powershell-safe"]

        {archive: $archive_file, output: $archive_unpack_dir} |
        to json --raw |
        powershell-safe -c '
            $in = ConvertFrom-Json -InputObject $Input
            Expand-Archive -LiteralPath $in.archive -DestinationPath $in.output
        '
        log info $'moving any nested files to ($archive_unpack_dir | to nuon)'
        do {
            cd $archive_unpack_dir
            glob --no-dir --no-symlink **
        } |
        where {|it| ($it | path dirname) != $archive_unpack_dir} |
        mv -v ...($in) $archive_unpack_dir
    } else if (which 7z | is-empty) {
        log info 'missing 7z, installing...'
        with-env {NU_LOG_LEVEL: 'debug'} {
            $nu.current-exe -c 'use package; package install 7zip'
        }
    }
    if (which 7z | is-empty) and $platform == 'windows' {
        log debug 'already unpacked archive'
    } else {
        log info $'unpacking to ($archive_unpack_dir | to nuon) with 7zip'
        7z e $'-o($archive_unpack_dir)' $archive_file
    }
    log info $'contents of ($archive_unpack_dir | to nuon)'
    ls $archive_unpack_dir

    let kanatas = (
        do {
            cd $archive_unpack_dir
            glob --no-dir --no-symlink --depth 1 *
        } |
        where {|it|
            let f = $it | path basename
            match $platform {
                'windows' => {($f has 'tty') and ($f has 'winIOv2') and ($f not-has 'cmd')},
                'linux' => {$f not-has 'cmd'},
                _ => {return (error make {msg: $'unsupported platform: ($platform)'})},
            }
        }
    )

    let kanata_exe = $kanatas | first
    log info $'choosing ($kanata_exe | to nuon) as the executable'

    log info $'copying ($kanata_exe | to nuon) kanata executable to ($output)'
    cp -v $kanata_exe $output

    log info 'checking to make sure it works'
    run-external $kanata_exe '--version'
    log info 'all works'
}

export def "download config" [
    # location to write configuration to
    output: path,
    # whether to force a redownload
    --force,
]: [nothing -> nothing] {
    let kanata_exe = (find exe)
    def "check config" [
        # path to config
        cfg: path,
    ]: [nothing -> bool] {
        if ($kanata_exe | is-empty) {
            log info 'could not check config, assuming it is okay'
            return true
        }
        log info $'using kanata to validate config'
        let result = do {$kanata_exe --cfg $output --check} | complete
        print $result.stdout
        print $result.stderr
        return ($result.exit_code == 0)
    }

    if (not $force) and ($output | path exists) {
        log info $'config file already exists in expected location: ($output)'
        let ok = (check config $output)
        if $ok {
            log warning $'problem with current config at ($output)'
            log warning $'redownloading config'
        } else {
            log info 'config is ok!'
            return null
        }
    }

    log info $'downloading config from: ($kanata_config_url)'
    http get --redirect-mode follow $kanata_config_url |
    save -f $output

    let ok = (check config $output)
    if not $ok {
        let msg = $'problem with current config: ($output)'
        log error $msg
        return (error make {msg: $msg})
    }
    log info 'config downloaded!'
}

export def "expected location config" []: [nothing -> list<path>] {
    let possible_config_dirs = [
        (if ($env has APPDATA) {$env.APPDATA | path join 'kanata'} else {null})
        ($env.XDG_CONFIG_HOME? | default ('~/.config' | path expand) | path join 'kanata')
        (if (which chezmoi | is-empty) {null} else {chezmoi dump-config --format=json | from json | get env.XDG_CONFIG_HOME?})
    ] | compact --empty

    let possible_config_files = $possible_config_dirs | each {path join 'kanata.kbd'}
    log info $"expected to find config file in one of:\n($possible_config_files | str join "\n")"
    return $possible_config_files
}

export def "find config" []: [nothing -> path] {
    let config_file = (expected location config | where {path exists} | get 0?)
    if ($config_file | is-empty) {
        let msg = 'could not find config in any of the expected locations'
        log error $msg
        return (error make {msg: $msg})
    }
    return $config_file
}

export def "find exe" [] {
    let kanatas = (
        with-env {PATH: (
            $env.PATH |
            uniq |
            where {path exists} |
            path expand --strict |
            append $env.EGET_BIN
        )} {which | where type == 'external' and command starts-with 'kanata'} |
        get path
    )
    $env.HOME = (
        $env |
        get HOME? USERPROFILE? |
        append [(
            if (which chezmoi | is-not-empty) {
                chezmoi dump-config --format=json |
                from json |
                get destDir
            } else {null}
        )] |
        append ($nu | get home-dir? home-path?) |
        compact --empty |
        first
    )
    let local_bin = $env.HOME | path join '.local' 'bin'
    let temp_kanata_bin = $local_bin | path join (match $platform {
        'windows' => 'kanata.exe',
        _ => 'kanata',
    })
    if ($kanatas | is-empty) {
        log warning $'did not find kanata; downloading to ($temp_kanata_bin | to nuon)'
        log info $'creating ($local_bin | to nuon)'
        mkdir -v $local_bin
        http get 
    }
}

export def main [--cfg: path = ""] {
    if (ps | where name =~ 'kanata' | is-not-empty) {
        log info "kanata already running"
        return
    }

    let cfg = if ($cfg | is-not-empty) {$cfg} else {
        $env.XDG_CONFIG_HOME |
        path join 'kanata' 'kanata.kbd'
    }
    run-external (find-kanata) '--cfg' $cfg
}

export def "run-kanata-windows" []: [nothing -> nothing] {
    let tmpdir = (mktemp -dt)
    let start_bat = $tmpdir | path join "start_kanata.bat"
    let lnk = (
        registry query --hkcu 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' 'Startup' |
        get value |
        path join 'kanata.lnk'
    )
    if not ($lnk | path exists) {
        log warning $'kanata.lnk does not exist, this will likely not work; expected at ($lnk | to nuon)'
    }
    echo $'start "" /min "($lnk)"' | save $start_bat

    try {cmd /u /d /e:on /f:off /v:off /q /c $start_bat}
    rm -rf $tmpdir
}

export def "create-shortcut" [
    # location to create shortcut at; defaults to shell:startup
    output?: path,
]: [nothing -> nothing] {
    if ($platform != "windows") {
        log warning $'expected platform to be windows, instead got: ($platform)'
        log warning 'creating a shortcut is unlikely to work'
    }

    let kanata_config_dir = (
        $env.XDG_CONFIG_HOME? |
        default ('~/.config' | path expand) |
        path join 'kanata'
    )
    mut kanata_config = $kanata_config_dir | path join 'kanata.kbd'

    if not ($kanata_config | path exists) {
        log warning $'downloading kanata config since it was not found at: ($kanata_config | to nuon)'
        http get --redirect-mode follow $kanata_config_url |
        save -f
    }

    use utils.nu ["powershell-safe"]
    # from: https://stackoverflow.com/a/9701907
    {
        exe: (find-kanata),
        dir: ($env.XDG_CONFIG_HOME | path join 'kanata')
    } | to json --raw |
    powershell-safe -c '
        $piped = ConvertFrom-Json -InputObject $Input
# from:
# https://stackoverflow.com/a/56454730
# https://learn.microsoft.com/en-us/powershell/scripting/samples/working-with-registry-entries
# finds shell:startup
        $startup = (Get-Item -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders").GetValue("Startup")
        $Shortcut = (New-Object -COMObject WScript.Shell).CreateShortcut("$startup\kanata.lnk")
        $Shortcut.TargetPath = $piped.exe
        # starts the window minimized
        $Shortcut.WindowStyle = 7
        $Shortcut.WorkingDirectory = $piped.dir
        $Shortcut.Description = "Runs kanata, with access to its config"
'
}
