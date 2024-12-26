use package/package_consts.nu ['default_package_manager_data_path', 'default_package_data_path']

export def main [] {
    data
}

export def "data" [] {
    [
        $default_package_manager_data_path,
        $default_package_data_path,
    ] | each {|it|
        if not ($it | path exists) {
            mkdir ($it | path dirname)
            touch $it
            $it
        } else if (not (nu-check $it)) {
            use std/log
            log error $'not a valid nu module! -> ($it)'
            log warning $'truncating -> ($it)'
            echo '' | save -f $it
            $it
        }
    }
}
