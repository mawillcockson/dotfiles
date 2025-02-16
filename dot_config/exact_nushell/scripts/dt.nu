export def "date my-format" [] {
    use clipboard.nu
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}

export def main [] { date my-format }
