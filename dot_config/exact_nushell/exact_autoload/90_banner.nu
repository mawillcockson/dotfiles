export const banner_once = r#'
    my-banner
    $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt |
        where {|it| $it != {code: $banner_once} }
    )
'#

export def --env "set banner hook" []: nothing -> nothing {
    $env.config.hooks.pre_prompt ++= [
        {code: ($banner_once)},
    ]
}

# just printing the banner results in it printing multiple times if the shell
# startup is odd. For instance, on Android, it's executed multiple times, and
# each time the banner is printed. If it were just printed each time, it would
# show multiple times. With a pre-prompt hook, it's not printed until an
# interactive prompt is shown.
#do {
#    use utils.nu ["banner-message colorful-default"]
#    (banner-message colorful-default) + "\n"
#}

set banner hook
