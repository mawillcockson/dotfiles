$ErrorActionPreference = "Stop"
# # Install and configure Windows Terminal
# # May be able to create a fragment file:
# # https://docs.microsoft.com/en-us/windows/terminal/json-fragment-extensions#applications-installed-from-the-web
# # Or could modify the user settings.json with jq
# # If the latter, would have to use the following for writing out the file,
# # because PowerShell uses UTF-16LE by default:
# # Write-Output $fragmentJson | Out-File $fragmentPath -Encoding Utf8
# if (-not (gcm winget -ErrorAction SilentlyContinue)) {
#     write-host "Install the 'App Installer' package through the Microsoft Store"
#     Pause
# }
# write-host "installing Windows Terminal"
# winget install `
#     --accept-source-agreements `
#     --accept-package-agreements `
#     "9N0DX20HK701" # Microsoft.WindowsTerminal msstore app ID
# write-host "configuring Windows Terminal with newly-installed fonts"
# $terminal_settings_file = "$Env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
# if (-not (Test-Path $terminal_settings_file)) {
#     # apparently, -Force "lets you create a file [...], even when the
#     # directories in the path do not exist":
#     # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item#example-3-create-a-profile
#     New-Item -Path $terminal_settings_file -ItemType "file" -Force
# }

$Env:PS_GUID = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
$Env:CMD_GUID = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}"
$Env:FONT = "DejaVuSansM Nerd Font"

# # Take the profiles list, and replace it with a new list. That new list is
# # constructed by selecting only the PowerShell and CMD profiles from the
# # original list, each modified to indicate the font face. Then to that list,
# # append the original list with the same two profiles removed. Then, set the
# # default profile to PowerShell. Implicitly return the whole input object.
# $jq_filter = '.profiles.list |= (' +
#     '[' +
#         '.[] | select(.guid == env.PS_GUID or .guid == env.CMD_GUID) | (' +
#             '.' +
#             '+' +
#             '{"font": {"face": env.FONT}}' +
#         ')' +
#     ']' +
#     '+' +
#     'del(.[] | select(.guid == env.PS_GUID or .guid == env.CMD_GUID))' +
# ') | .defaultProfile = env.PS_GUID'
# # Double-quote characters need to be escaped when passed to external programs,
# # as described in this aggressively formatted answer:
# # https://stackoverflow.com/a/59036879
# $jq_filter = $jq_filter -replace '"','\"'
# $new_contents = (cat $terminal_settings_file `
#     | jq --indent 4 $jq_filter)
# Out-File -FilePath $terminal_settings_file -InputObject $new_contents -Encoding utf8

# https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions
$fragments_dir = "$Env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments"
$program = "catppuccin"
if (-not (Test-Path -PathType Container -Path $fragments_dir\$program)) {
    New-Item -Path $fragments_dir -ItemType Directory -Name $program -Force
}
$Env:LATTE = (iwr -useb "https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/latte.json").Content
$Env:LATTE_THEME = (iwr -useb "https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/latteTheme.json").Content
$Env:MOCHA = (iwr -useb "https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/mocha.json").Content
$Env:MOCHA_THEME = (iwr -useb "https://github.com/catppuccin/windows-terminal/raw/4d8bb2f00fb86927a98dd3502cdec74a76d25d7b/mochaTheme.json").Content
$jq_filter = '{"profiles": [' +
        '{' +
            '"updates": env.PS_GUID,' +
            '"colorScheme": {' +
                '"light": "Catppuccin Latte",' +
                '"dark": "Catppuccin Mocha",' +
            '},' +
            '"font": {' +
                '"face": env.FONT,' +
            '},' +
        '},' +
        '{' +
            '"updates": env.CMD_GUID,' +
            '"colorScheme": {' +
                '"light": "Catppuccin Latte",' +
                '"dark": "Catppuccin Mocha",' +
            '},' +
            '"font": {' +
                '"face": env.FONT,' +
            '},' +
        '}' +
    '],' +
    '"schemes": [env.LATTE | fromjson, env.MOCHA | tostring | fromjson],' +
    '"themes": [env.LATTE_THEME | fromjson, env.MOCHA_THEME | tostring | fromjson]}'
$jq_filter = $jq_filter -replace '"','\"'
jq --indent 4 --null-input $jq_filter |
    out-file -FilePath "$fragments_dir\$program\profile_updates.json" -Encoding utf8
