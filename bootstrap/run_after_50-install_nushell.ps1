Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if (-not (Get-AppxPackage Microsoft.DesktopAppInstaller)) {
    Add-AppxPackage "https://aka.ms/getwinget"
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
}

winget install --id "Nushell.Nushell" --exact --accept-package-agreements --accept-source-agreements --disable-interactivity --scope "user"

if ($LastExitCode -ne 0) {
    throw "error with winget"
}
