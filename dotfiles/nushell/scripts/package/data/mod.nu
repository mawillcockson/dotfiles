export use package/data/simple_add.nu ['simple-add']
export use package/data/save_load.nu ['save-data', 'load-data', 'data-diff']
export use package/data/validate_data.nu ['validate-data']

# add a package to the package metadata file (use `package path` to list it)
export def add [
    # the package manager-independent identifier
    name: string,
    # a record of the platforms it can be installed on, and the package
    # managers and identifiers that can be used to install it
    install: record,
    # optionally save this single record to the default data file
    --save,
    # these are used in searching, to help find a package
    --search-help: list<string>,
    # used in sorting, selecting, and searching
    --tags: list<string>,
    # explanations and notes about the packages
    --reasons: list<string>,
    # URLs to repositories and documentation
    --links: list<string>,
] {
    if $save {
        load-data |
        simple-add $name $install --search-help $search_help --tags $tags --reasons $reasons --links $links |
        save-data
    } else {
        simple-add $name $install --search-help $search_help --tags $tags --reasons $reasons --links $links
    }
}
