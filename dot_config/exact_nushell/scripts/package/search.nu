use package/data

# helper function for scripts to make filtering package data slightly easier
export def exact [
    name: string
]: [
    record -> record
    nothing -> record
] {
    (
        default (data load-data)
        | get $name
        | insert name $name
        | move --before install name
    )
}

# helper function for human to make searching package data easier
export def main [
    # the search term
    name: string,
]: [
    record -> list<record>
    nothing -> list<record>
] {
    default (data load-data) |
    transpose name data | where {|it|
    (
        ($name in $it.name)
        or
        ($it.data.search_help | any {|e| $name in $e})
        or
        ($it.data.tags | any {|e| $name in $e})
        or
        ($it.data.links | any {|e| $name in $e})
        or
        ($it.data.reasons | any {|e| $name in $e})
    )} | (
        # NOTE::IMPROVEMENT
        # may be able to replace this with `into record`
        transpose --header-row --as-record
    ) |
    items {|name,rec|
        $rec |
        insert name $name |
        move --before install name
    }
}
