[CmdletBinding(DefaultParameterSetName="download")]
param(
    [PSDefaultValue(Help = "whether to redownload the executable and config file")]
    [Alias("force")]
    [Parameter(ParameterSetName="download")]
    [bool]$redownload = $false
    [PSDefaultValue(Help = "whether to run the uninstallation instead")]
    [Alias("remove")]
    [Parameter(ParameterSetName="remove")]
    [bool]$uninstall = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$github_latest_release_url = "https://api.github.com/repos/jtroo/kanata/releases/latest"
$kanata_config_url = "https://github.com/mawillcockson/dotfiles/raw/refs/heads/main/dot_config/kanata/kanata.kbd"

$config_dir = Join-Path [Environment]::GetFolderPath("ApplicationData") "kanata"
$json = Join-Path $config_dir "kanata_latest.json"
$exe_dir = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), ".local", "bin")
$exe = = Join-Path $exe_dir "kanata.exe"
$config = Join-Path $config_dir "kanata.kbd"

$existing_exe = $exe
if (-not (Test-Path -LiteralPath $existing_exe)) {
    $existing_exe = (
        Get-Command -CommandType Application |
        Where-Object -Property "Name" -Like -Value "kanata*" |
        Select-Object -First 1
    )
}
if ($existing_exe -and (-not $uninstall)) {
    echo "testing existing command to see if it works: $existing_exe"
    try {
        & $existing_exe --version
        echo "current exe worked, $(if ($redownload) {'but redownloading anyways'} else {'not redownloading'})"
    } catch {
        Write-Warning "problem with current exe, redownloading"
        Set-Variable -Name "redownload" -Value $true -Scope Script -Description "whether to redownload the kanata executable and config, or not"
    }
} elseif ($uninstall) {
    Write-Verbose "not testing $existing_exe, since we'll be removing it"
}

if (-not ((Test-Path -LiteralPath $json) -or $uninstall)) {
    echo "downloading latest kanata release info to: $json"
    irm -useb -uri $github_latest_release_url -outfile $json
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
if (-not ((Test-Path -LiteralPath $archive) -or $uninstall)) {
    echo "archive file doesn't exist, redownloading"
    irm -useb -uri $archive_asset.browser_download_url -outfile $archive
    $archive = Get-Item -LiteralPath $archive
    $archive_unpack_dir = Join-Path $config_dir $archive.BaseName

    echo "unpacking archive to $archive_unpack_dir"
    Expand-Archive -LiteralPath $archive -DestinationPath $archive_unpack_dir -Force
}
$kanatas = (
    Get-ChildItem -LiteralPath $archive_unpack_dir |
    Where-Object {
        $_ -ilike "*tty*"
        -and
        $_ -ilike "*winIOv2*"
        -and
        $_ -inotlike "*cmd_allowed*"
    }
)
$kanata_exe = Select-Object -InputObject $kanatas -First 1
if (-not ((Test-Path -LiteralPath $existing_exe) -or $redownload)) {
    echo "found exe from archive to use: $kanata_exe"
    Copy-Item -Verbose -LiteralPath $kanata_exe -Destination $exe
    echo "testing command to see if it works: $exe"
    try {
        & $exe --version
        echo "current exe worked, $(if ($redownload) {'but redownloading anyways'} else {'not redownloading'})"
    } catch {
        throw "problem with current exe"
    }
} else {
    echo "not copying $kanata_exe since $exe already exists"
}

function Check-Config {
    echo "checking config with kanata"
    & $exe --cfg $exe --check
}

$downloaded = $false
$redownload_config = $redownload
if (-not $redownload_config -and (Test-Path -LiteralPath $config)) {
    echo "config already exists at $config"
    try {Check-Config}
    catch {
        Write-Warning "problem with config $config, redownloading"
        $redownload_config = $true
    }
}
if ($redownload_config -or (-not (Test-Path -LiteralPath $config))) {
    echo "downloading config to: $config"
    irm -useb -uri "https://github.com/mawillcockson/dotfiles/raw/main/dot_config/kanata/kanata.kbd" -outfile $config
    Check-Config
}

Start-Process -FilePath $exe -ArgumentList "--cfg", $config -WorkingDirectory $config_dir -WindowStyle Minimized
