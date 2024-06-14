# provide a closure that implements installing a single package with the named
# package manager
#
# this returns a data structure that `package manager save` can persist to disk
export def add [
    # the default for platform is whatever the current platform is
    --platform: string = ($nu.os-info.name),
    # the name of the package manager, used in `package add`
    name: string,
    # the closure that is passed a package id, and expected to install the package
    closure: closure,
] {
    # the insert command itself takes a closure as the second argument, so the
    # closure has to be wrapped in a closure that, when executed, returns the
    # $closure
    default {} | insert ([$platform, $name] | into cell-path) {|row| $closure}
}

# generate all the package manager data
#
# modify this function to register more package managers
export def "generate-data" [] {
    # add --platform 'platform' 'manager' {|id: string| print $'installing ($id)'}
    add --platform 'windows' 'scoop' {|id: string| use utils.nu ['powershell-safe']; $id | powershell-safe -c $"scoop install $Input"} |
    add --platform 'windows' 'winget' {|id: string| ^winget install --id $id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity} |
    add --platform 'windows' 'pipx' {|id: string| ^pipx install $id} |
    add --platform 'android' 'pkg' {|id: string| ^pkg install $id} |
    add --platform 'windows' 'eget' {|id: string| ^eget /quiet $id}
}
