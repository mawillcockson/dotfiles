use std [assert]

use $'($nu.default-config-dir)/scripts/package'

#[test]
def test_path [] {
    assert equal (package data path) ($nu.default-config-dir | path join 'scripts' 'package' 'data.nuon')
}
