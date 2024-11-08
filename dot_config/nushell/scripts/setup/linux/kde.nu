export def main [] {
}

export def "set user avatar" [] {
    use consts.nu [platform]
    use package/manager
    let apt_get = (
        manager load-data |
        get $platform |
        get apt-get
    )

    do $apt_get 'graphicsmagick'

    let tmpfile = (mktemp)
    http get --max-time 3 'https://willcockson.family/s/flower.jpg' |
    save -f $tmpfile

    cp $tmpfile ~/.face

    rm $tmpfile
}

# doing anything more than the above is going to take quite a bit of effort, it seems:
# https://www.reddit.com/r/kde/comments/m0nj54/how_to_open_kde_plasma_system_settings_using/
# https://www.reddit.com/r/kde/comments/eyy7ve/how_to_change_system_settings_in_kde_plasma_using/
# https://wiki.archlinux.org/title/KDE
# https://discuss.kde.org/t/reset-all-plasma-settings-at-once-and-start-tiling-feature-on-command-line/9503
# https://superuser.com/questions/488232/how-to-set-kde-desktop-wallpaper-from-command-line
# https://www.reddit.com/r/kde/comments/65pmhj/comment/icfca29/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button#:%7E:text=kwriteconfig5%20%2D%2Dfile%20%22$HOME/.config/plasma%2Dorg.kde.plasma.desktop%2Dappletsrc%22%20%2D%2Dgroup%20%27Containments%27%20%2D%2Dgroup%20%271%27%20%2D%2Dgroup%20%27Wallpaper%27%20%2D%2Dgroup%20%27org.kde.image%27%20%2D%2Dgroup%20%27General%27%20%2D%2Dkey%20%27Image%27%20%22/path/to/file.png%22
# https://github.com/pashazz/ksetwallpaper/blob/master/ksetwallpaper.py
