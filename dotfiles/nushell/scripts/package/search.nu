use package/data.nu
use package/manager.nu
use utils.nu ["get c-p"]

# helper function to make filtering package data easier
export def main [
    # the search term
    name: string,
    # name is treated as text and must match exactly
    --exact,
] {
    let package_data = (if ($in | is-not-empty) {$in} else {
        $env |
        get PACKAGE_DATA? |
        if ($in | is-not-empty) {
            $in
        } else {
            (data generate).data
        }
    })
    if $exact {
        $package_data | get c-p --optional [($name)] | if ($in | is-empty) {$in} else {
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
