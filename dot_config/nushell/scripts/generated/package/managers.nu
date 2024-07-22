# this file is auto-generated
# please use `package manager add --save` instead

# returns the package manager data
export def "package-manager-load-data" [] {
    use package/manager/simple_add.nu ['simple-add']
    simple-add --platform "windows" "scoop" {|id: string| use utils.nu ['powershell-safe']; $id | powershell-safe -c $"scoop install $Input"} |
    simple-add --platform "windows" "winget" {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity} |
    simple-add --platform "windows" "pipx" {|id: string| ^python -X utf8 -m pipx install $id} |
    simple-add --platform "windows" "eget" {|id: string| ^eget /quiet $id} |
    simple-add --platform "windows" "cargo" {|id: string| ^cargo --bins --all-features --keep-going $id} |
    simple-add --platform "linux" "apt-get" {|id: string| ^apt-get --no-install-recommends --quiet --assume-yes --default-release --update install $id } |
    simple-add --platform "android" "pkg" {|id: string| ^pkg install $id}
}
