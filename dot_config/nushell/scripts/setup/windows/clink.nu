export def main [] {
    mkdir (clink_dir)
    clink autorun install -- --profile (clink_dir)
}

export def clink_dir [] {
    $env.XDG_CONFIG_HOME |
    path join 'clink'
}
