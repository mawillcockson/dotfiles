use std [assert]

use $'($nu.default-config-dir)/scripts/package'

#[test]
def test_it [] {
    assert equal (package path) ($nu.default-config-dir | path join 'scripts' 'package' 'data.nuon')
}
