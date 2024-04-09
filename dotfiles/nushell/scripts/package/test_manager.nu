use std [assert]

use $'($nu.default-config-dir)/scripts/package/manager.nu'

#[test]
def test_path [] {
    let manager_data_path = (manager data-path)
    assert equal ($manager_data_path) ($nu.default-config-dir | path join 'scripts' 'generated' 'package' 'managers.nu')
}

#[test]
def test_add_one [] {
    let closure = {|id: string| print $'example closure installing: ($id)'}
    let data = manager add --platform 'platform' 'package manager' $closure
    assert ($data == {'platform': {'package manager': ($closure)}})
}

#[test]
def test_add_two [] {
    let closures = {
        'closure1': {|id: string| print $'example package manager1 installing: ($id)'},
        'closure2': {|id: string| print $'example package manager2 installing: ($id)'},
    }
    let data = (
        manager add --platform 'platform' 'package manager1' $closures.closure1 |
        manager add --platform 'platform' 'package manager2' $closures.closure2
    )
    assert ($data == {
        'platform': {
            # intentionally in a different order
            'package manager2': ($closures.closure2),
            'package manager1': ($closures.closure1),
        },
    })
}

#[test]
def test_missing [] {
    # this is really testing `==` and `!=`
    let closures = {
        'closure1': {|id: string| print $'example package manager1 installing: ($id)'},
        'closure2': {|id: string| print $'example package manager2 installing: ($id)'},
    }
    let data = (
        manager add --platform 'platform' 'package manager1' $closures.closure1 |
        manager add --platform 'platform' 'package manager2' $closures.closure2
    )
    assert ($data != {
        'platform': {
            # intentionally missing one
            'package manager1': ($closures.closure1),
        },
    })
}

#[test]
def test_many [] {
    let closures = {
        'closure1': {|id: string| print $'example package manager1 installing: ($id)'},
        'closure2': {|id: string| print $'example package manager2 installing: ($id)'},
        'closure3': {|id: string| print $'example package manager3 installing: ($id)'},
    }
    let data = (
        manager add --platform 'platform1' 'package manager1' $closures.closure1 |
        manager add --platform 'platform1' 'package manager2' $closures.closure2 |
        manager add --platform 'platform2' 'package manager3' $closures.closure3
    )
    assert ($data == {
        'platform1': {
            # intentionally in a different order
            'package manager2': ($closures.closure2),
            'package manager1': ($closures.closure1),
        },
        'platform2': {'package manager3': ($closures.closure3)},
    })
}
