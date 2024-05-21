const scripts = $'($nu.default-config-dir)/scripts'
export use $'($scripts)/clipboard.nu'
export def "date my-format" [] {
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}

export def main [] { date my-format }
