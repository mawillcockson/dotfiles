# powershell -ex remotesigned -noprofile -c 'irm -useb "https://github.com/mawillcockson/dotfiles/raw/main/dotfiles/packages/windows_install.ps1" | iex'

# https://github.com/PowerShell/PowerShell/issues/3415#issuecomment-1354457563
if ($host.version.Major -eq 7 && $host.version.Minor -ge 4) {
    Enable-ExperimentalFeature PSNativeCommandErrorActionPreference
}
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

Invoke-RestMethod -UseBasicParsing -Uri 'https://get.scoop.sh' | Invoke-Expression
scoop install aria2 git nu
nu -c 'let tmpfile = (mktemp); http get "https://github.com/mawillcockson/dotfiles/raw/main/dotfiles/packages/install_dotfiles.nu" | save -f $tmpfile; run-external $nu.executable $tmpfile; rm -f $tmpfile'
