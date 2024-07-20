use package/data

# helper function to make filtering package data easier
export def main [
    # the search term
    name: string,
    # name is treated as text and must match exactly
    --exact,
] {
    let package_data = default (data load-data)
    if $exact {
        $package_data |
        get ([($name)] | into cell-path) |
        insert name $name |
        move --before install name
    } else {
        $package_data | transpose name data | filter {|it|
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
        )} | transpose --header-row --as-record |
        items {|name,rec|
            $rec |
            insert name $name |
            move --before install name
        }
    }
}
