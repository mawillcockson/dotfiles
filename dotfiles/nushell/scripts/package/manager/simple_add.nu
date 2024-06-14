# provide a closure that implements installing a single package with the named
# package manager
#
# this returns a data structure that `package manager save-data` can persist to disk
export def "simple-add" [
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
