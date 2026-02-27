[CmdletBinding(DefaultParameterSetName="download")]
param(
    [PSDefaultValue(Help = "whether to redownload the executable and config file")]
    [Alias("force")]
    [Parameter(ParameterSetName="download")]
    [switch]$redownload,
    [PSDefaultValue(Help = "whether to run the uninstallation instead")]
    [Alias("remove")]
    [Parameter(ParameterSetName="remove")]
    [switch]$uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$github_latest_release_url = "https://api.github.com/repos/jtroo/kanata/releases/latest"
$kanata_config_url = "https://github.com/mawillcockson/dotfiles/raw/refs/heads/main/dot_config/kanata/kanata.kbd"

$config_dir = Join-Path ([Environment]::GetFolderPath("ApplicationData")) "kanata"
$json = Join-Path $config_dir "kanata_latest.json"
$exe_dir = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), ".local", "bin")
$exe = Join-Path $exe_dir "kanata.exe"
$config = Join-Path $config_dir "kanata.kbd"

function Check-IsRunning {
    param ([string]$executable = "")
    if ($executable -eq "") {
        return [bool](Get-Process -Name "*kanata*")
    }
    return [bool](Get-Process | Where-Object -FilterScript {$_.Path -eq $executable})
}

If (((Check-IsRunning) -and (-not $redownload)) -and (-not $uninstall)) {
    echo "kanata is already running"
    Exit 0
}

$existing_exe = $exe
if (-not (Test-Path -LiteralPath $existing_exe)) {
    $existing_exe = (
        Get-Command -CommandType Application |
        Where-Object -Property "Name" -Like -Value "kanata*" |
        Select-Object -First 1
    )
}
if (($existing_exe -and (-not $uninstall)) -and (-not $redownload)) {
    echo "testing existing command to see if it works: $existing_exe"
    & $existing_exe --version
    if ($?) {
        echo "current exe worked, $(if ($redownload) {'but redownloading anyways'} else {'not redownloading'})"
    } else {
        Write-Warning "problem with current exe, redownloading"
        Set-Variable -Name "redownload" -Value $true -Scope Script -Description "whether to redownload the kanata executable and config, or not"
    }
} elseif ($uninstall) {
    echo "not testing $existing_exe, since we'll be removing it"
} elseif ($redownload) {
    echo "not testing $existing_exe, since we'll be redownloading"
} else {
    throw "missed a branch"
}

if ($uninstall) {
    if ((Split-Path -Parent -Path $json) -eq $config_dir) {
        Write-Verbose "removing $json later"
    } else {
        Remove-Item -Verbose -Force -LiteralPath $json
    }
} elseif ($redownload -or (-not (Test-Path -LiteralPath $json))) {
    New-Item -Verbose -Path (Split-Path -Parent -Path $json) -ItemType Directory -Force
    echo "downloading latest kanata release info to: $json"
    irm -useb -uri $github_latest_release_url -outfile $json
} else {
    echo "latest kanata release info already downloaded"
}

$archive_asset = (
    Get-Content -Raw -LiteralPath $json |
    ConvertFrom-Json |
    Select-Object -ExpandProperty "assets" |
    Where-Object -Property "name" -Like -Value "*windows*" |
    Where-Object -Property "name" -Like -Value "*x64*" |
    Where-Object -Property "name" -Like -Value "*.zip" |
    Select-Object -First 1
)
if (-not $archive_asset) {
    throw "could not find a suitable archive to download in $json"
}
$archive = Join-Path $config_dir $archive_asset.name
$archive_unpack_dir = Join-Path $config_dir ([System.IO.Path]::GetFilenameWithoutExtension($archive))
if ($uninstall) {
    if ((Split-Path -Parent -Path $archive) -eq $config_dir) {
        Write-Verbose "removing $archive later"
    } else {
        Remove-Item -Verbose -Force -LiteralPath $archive
    }
} elseif ($redownload -or (-not (Test-Path -LiteralPath $archive))) {
    New-Item -Verbose -Path (Split-Path -Parent -Path $archive) -ItemType Directory -Force
    echo "archive file doesn't exist, redownloading"
    irm -useb -uri $archive_asset.browser_download_url -outfile $archive
} else {
    echo "already downloaded $archive"
}

function Get-KanataExe {
    Write-Verbose "checking for executable in $archive_unpack_dir"
    return (
        Get-ChildItem -LiteralPath $archive_unpack_dir |
        Where-Object -FilterScript {
            (($_ -ilike "*tty*") -and ($_ -ilike "*winIOv2*")) -and ($_ -inotlike "*cmd_allowed*")
        } |
        Select-Object -First 1 | % {$_.FullName}
    )
}
$kanata_exe = @()
if (Test-Path -LiteralPath $archive_unpack_dir) {
    $kanata_exe = (Get-KanataExe)
}

if ($uninstall -and (Test-Path -LiteralPath $archive_unpack_dir)) {
    Remove-Item -Verbose -Force -Recurse -LiteralPath $archive_unpack_dir
} elseif ($redownload -or (-not $kanata_exe)) {
    echo "unpacking archive to $archive_unpack_dir"
    Expand-Archive -LiteralPath $archive -DestinationPath $archive_unpack_dir -Force
    $kanata_exe = (Get-KanataExe)
    if (-not $kanata_exe) {
        throw "could not find a suitable executable in $archive_unpack_dir"
    }
} else {
    echo "already found a suitable executable: $kanata_exe"
}

function Check-Exe {
    param ([string]$exe)
    echo "testing command to see if it works: $exe"
    & $exe --version
    if (-not $?) {
        throw "problem with current exe"
    }
}

if ($uninstall) {
    if (Check-IsRunning $exe) {
        echo "stopping any process that has kanata in the name"
        Stop-Process -Verbose -Name "*kanata*"
    }
    Remove-Item -Verbose -Force -LiteralPath $exe -ErrorAction Continue
}
$recopy_exe = $redownload
if ($uninstall) {
    Write-Verbose "already removed $exe"
} elseif ((-not $recopy_exe) -and $existing_exe) {
    try {Check-Exe $existing_exe}
    catch {
        Write-Warning "problem with $existing_exe, recopying"
        $recopy_exe = $true
    }
}
if ($uninstall) {
    Write-Verbose "still already removed $exe"
} elseif ($recopy_exe -or (-not (Test-Path -LiteralPath $exe))) {
    echo "found exe from archive to use: $kanata_exe"
    $kanata_process = Get-Process | Where-Object -FilterScript {$_.Path -eq $exe}
    if ($kanata_process) {
        echo "stopping kanata to copy $kanata_exe to $exe -> $kanata_process"
        Stop-Process -Verbose -InputObject $kanata_process
    }
    Copy-Item -Verbose -LiteralPath $kanata_exe -Destination $exe
    Check-Exe $exe
} else {
    echo "not copying $kanata_exe since $exe already exists"
}

function Check-Config {
    echo "using kanata to check config: $config"
    & $exe --cfg $config --check
    if (-not $?) {
        throw "problem with configuration $config"
    }
}

$redownload_config = $redownload
if ($uninstall) {
    Remove-Item -Verbose -Force -Recurse -LiteralPath $config_dir
    if ((Split-Path -Parent -Path $config) -ne $config_dir) {
        Remove-Item -Verbose -Force -LiteralPath $config
    }
} elseif ((Test-Path -LiteralPath $config) -and (-not $redownload_config)) {
    echo "config already exists at $config"
    echo "checking config with kanata"
    try {Check-Config}
    catch {
        Write-Warning "problem with config $config, redownloading"
        $redownload_config = $true
    }
}
if ($uninstall) {
    Write-Verbose "not redownloading config"
} elseif ($redownload_config -or (-not (Test-Path -LiteralPath $config))) {
    New-Item -Verbose -Path (Split-Path -Parent -Path $config) -ItemType Directory -Force
    echo "downloading config to: $config"
    irm -useb -uri $kanata_config_url -outfile $config
    echo "checking config with kanata"
    Check-Config
}

if ($uninstall) {
    echo "finished uninstalling kanata"
} elseif (Check-IsRunning) {
    echo "kanata already running, but I don't know how"
} else {
    Start-Process -FilePath $exe -ArgumentList "--cfg", $config -WorkingDirectory $config_dir -WindowStyle Minimized
    echo "kanata should have been started"
}
