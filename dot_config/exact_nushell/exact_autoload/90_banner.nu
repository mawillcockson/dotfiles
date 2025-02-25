export const banner_once = r#'
    my-banner
    $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt |
        filter {|it| $it != {code: $banner_once} }
    )
'#

export def --env "set banner hook" []: nothing -> nothing {
    $env.config.hooks.pre_prompt ++= [
        {code: ($banner_once)},
    ]
}

do {
    use utils.nu ["banner-message colorful-default"]
    (banner-message colorful-default) + "\n"
}
