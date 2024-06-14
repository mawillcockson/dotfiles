# this file is auto-generated
# please edit scripts/package/manager.nu instead

# returns the package manager data
export def "package-manager-load-data" [] {
{
    "windows": {
        "scoop": {|id: string| $id | powershell-safe -c $"scoop install $Input"},
        "winget": {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity},
        "pipx": {|id: string| ^pipx install $id},
        "eget": {|id: string| ^eget /quiet $id},
    },
    "android": {
        "pkg": {|id: string| ^pkg install $id},
    },
}
}