# defined in env.nu
# const default_package_data_path = $'($nu.default-config-dir)/scrupts/generated/package/'

export use manager.nu
export use data.nu
export use data.nu [add]

# returns the path of the main package data file
export def "data path" [] {
    # this function is here because I don't want to shadow `path` in the
    # data.nu module
    (
        scope variables
        | where name == '$default_package_data_path'
        | get value?
        | compact --empty
        | default [] # sometimes the value returned by `get` is an empty list, and not `null`
        | append $'($nu.default-config-dir)/scripts/generated/package/data.nuon'
        | first
        | if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}

# returns the path of the custom package install commands file
export def "customs data-path" [] {
    # this function is here because I'm not sure where else to put it
    (
        scope variables
        | where name == '$default_package_customs_path'
        | get value?
        | compact --empty
        | default [] # sometimes the value returned by `get` is an empty list, and not `null`
        | append $'($nu.default-config-dir)/scripts/generated/package/customs.nu'
        | first
        | if ($in | path exists) == true {
            ls --all --full-paths $in | get 0.name
        } else {
            $in
        }
    )
}
