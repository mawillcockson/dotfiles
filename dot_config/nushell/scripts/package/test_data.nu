use std [assert]

use $'($nu.default-config-dir)/scripts/package'

#[test]
def test_path [] {
    let package_data_path = (package data path)
    assert equal ($package_data_path) ($nu.default-config-dir | path join 'scripts' 'generated' 'package' 'data.nuon')
}

#[test]
def test_simple [] {
    $env.PACKAGE_MANAGER_DATA = (package manager add 'example-manager' {|id: string| print $'installing ($id) with example-manager'})
    let example_data = (
        package add 'example-name' {'example-platform': {'example-manager': 'example-id'}}
            --search-help ['additional string']
            --tags ['example-tag']
            --reasons ['example-reason']
            --links ['example-link']
    )
    assert equal $example_data ({
        'customs': {},
        'data': {
            'example-name': {
                'install': {
                    'example-platform': {
                        'example-manager': 'example-id',
                    },
                },
                'search_help': ['additional string'],
                'tags': ['example-tag'],
                'reasons': ['example-reason'],
                'links': ['example-link'],
            },
        },
    })
}
