use package/data.nu
use package/manager.nu

# helper function to make filtering package data easier
export def main [
    # the search term
    name: string,
    # name is treated as text and must match exactly
    --exact,
] {
    let package_data = (default ($env | get PACKAGE_DATA? | default ((data generate).data)))
    if $exact {
        $package_data | get ([{'value': ($name), 'optional': true}] | into cell-path) | if ($in | is-empty) {$in} else {
            {$name: $in}
        }
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
        )} | transpose --header-row --as-record
    }
}
