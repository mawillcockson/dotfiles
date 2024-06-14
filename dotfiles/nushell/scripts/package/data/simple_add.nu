# add a package to the package metadata file (use `package path` to list it)
export def "simple-add" [
    # the package manager-independent identifier
    name: string,
    # a record of the platforms it can be installed on, and the package
    # managers and identifiers that can be used to install it
    install: record,
    # these are used in searching, to help find a package
    --search-help: list<string>,
    # used in sorting, selecting, and searching
    --tags: list<string>,
    # explanations and notes about the packages
    --reasons: list<string>,
    # URLs to repositories and documentation
    --links: list<string>,
] {
    # `default` here will absorb the piped input and return that instead of the
    # empty structure
    default {} |
        # I'm inserting into a record so that any calls to `add` that have a
        # duplicate package name will produce an error at the command that
        # tries to insert it
        insert ($name) {
        'install': $install,
        'search_help': ($search_help | default []),
        'tags': ($tags | default []),
        'reasons': ($reasons | default []),
        'links': ($links | default []),
    }
}
