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
