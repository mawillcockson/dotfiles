use package/manager/simple_add.nu ['simple-add']
export use package/manager/save_load.nu ['save-data', 'load-data']

# can also save the data
export def add [
    # the default for platform is whatever the current platform is
    --platform: string = ($nu.os-info.name),
    # add this single record to the default data file
    --save,
    # the name of the package manager, used in `package add`
    name: string,
    # the closure that is passed a package id, and expected to install the package
    closure: closure,
] {
    if $save {
        load-data |
        simple-add --platform $platform $name $closure |
        save-data
    } else {
        simple-add --platform $platform $name $closure
    }
}
