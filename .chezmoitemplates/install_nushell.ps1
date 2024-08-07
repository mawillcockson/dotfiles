Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

if (-not (gcm nu -ErrorAction SilentlyContinue)) {
    if (-not (Get-AppxPackage Microsoft.DesktopAppInstaller)) {
        Add-AppxPackage "https://aka.ms/getwinget"
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    }

    winget install --id "Nushell.Nushell" --exact --accept-package-agreements --accept-source-agreements --disable-interactivity --scope "user"

    if ($LastExitCode -ne 0) {
        throw "error with winget"
    }
} else {
    Write-Host "nushell already installed"
}

#{{ with .minimum_nu_version }}
nu -c @'
use std [log]
if (
    version |
    select major minor patch |
    into int major minor patch |
    (
        ($in.major >= {{ .major }})
        and
        ($in.minor >= {{ .minor }})
        and
        ($in.patch >= {{ .patch }})
    )
) {
    log info 'nu version is new enough'
    exit 0
} else {
    log error 'nu version is not new enough'
    exit 1
}
'@
#{{ end }}

if ($LastExitCode -ne 0) {
    throw "nushell not new enough"
}
