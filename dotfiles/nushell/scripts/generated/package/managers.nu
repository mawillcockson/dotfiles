# this file is auto-generated
# please edit scripts/package/manager.nu instead

# returns the package manager data
export def "package-manager-load-data" [] {
    use package/manager_add.nu ['add']
    add --platform "windows" "scoop" {|id: string| use utils.nu ['powershell-safe']; $id | powershell-safe -c $"scoop install $Input"} |
    add --platform "windows" "winget" {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity} |
    add --platform "windows" "pipx" {|id: string| ^pipx install $id} |
    add --platform "windows" "eget" {|id: string| ^eget /quiet $id} |
    add --platform "android" "pkg" {|id: string| ^pkg install $id}
}