# this file is auto-generated
# please use `package add --save` instead

# returns the package data
export def "package-data-load-data" [] {
    use package/data/simple_add.nu ['simple-add']
    use package/data/validate_data.nu ['validate-data']

    simple-add "winget" {"windows": {"custom": {||
        use utils.nu [powershell-safe]
        powershell-safe -c ([
            'if (-not (Get-AppxPackage Microsoft.DesktopAppInstaller)) {',
            '    Add-AppxPackage "https://aka.ms/getwinget"',
        # https://learn.microsoft.com/en-us/windows/package-manager/winget/
            '    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe',
            '}',
        ] | str join '')
    }}} --tags [want, "package manager"] |
    simple-add "scoop" {"windows": {"custom": {||
        use utils.nu [powershell-safe]
        powershell-safe --less-safe -c ([
            'if (-not (gcm scoop -ErrorAction SilentlyContinue)) {',
            '    irm -useb "https://get.scoop.sh" | iex',
            '    scoop install aria2 git',
            '    scoop bucket add extras',
            '}',
        ] | str join '')
    }}} --tags [want, "package manager"] |
    simple-add "pipx" {"windows": {"custom": {|install: closure|
        do $install 'scoop'
        do $install 'python'
        ^python -X utf8 -m pip install --user --upgrade pip setuptools wheel pipx
        ^python -X utf8 -m pipx ensurepath
    }}} --tags [want, "package manager"] |
    simple-add "cargo" {"windows": {"custom": {|install: closure|
        do $install 'rustup'
        if (which 'cargo' | is-empty) {
            ^rustup default stable-msvc
        }
        ^cargo --version
    }}} --tags ["package manager", rust, language, tooling] --links ["https://rustup.rs/"] |
    simple-add "apt-get" {"linux": {"custom": {||
        if (which apt-get | is-empty) {
            return (error make {
                'msg': "apt-get not found!"
            })
        }
    }}} --tags ["package manager", presumed] |
    simple-add "pkg" {"android": {"custom": {|install: closure|
        if (which pkg | is-empty) {
            return (error make {
                'msg': 'pkg not found! cannot install anything',
            })
        }
    }}} --tags ["package manager", presumed] |
    simple-add "flatpak" {"linux": {"apt-get": "flatpak"}} --tags ["flatpak", "package manager"] --reasons ["cross-distribution package manager that is farily well-used"] --links ["https://flatpak.org/setup/Debian"] |
    simple-add "flathub" {"linux": {"custom": {|install: closure|
        do $install 'flatpak'
        try { flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo }
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    }}} --tags ["flatpak"] |
    simple-add "pyenv" {"linux": {"custom": {|install: closure|
        use std [log]
        if (which 'pyenv' | is-not-empty) {
            log info 'pyenv already installed'
            return true
        }

        log info 'installing prerequisites'
        do $install 'apt-get'
        # https://github.com/pyenv/pyenv/wiki#suggested-build-environment
        ^sudo apt-get update --assume-yes
        (
            ^sudo apt-get install
                --no-install-recommends
                --quiet
                --assume-yes
                --default-release stable
                build-essential
                libssl-dev
                zlib1g-dev
                libbz2-dev
                libreadline-dev
                libsqlite3-dev
                curl
                git
                libncursesw5-dev
                xz-utils
                tk-dev
                libxml2-dev
                libxmlsec1-dev
                libffi-dev
                liblzma-dev
        )

        let $tmpfile = (mktemp)
        http get --max-time 3 'https://pyenv.run' | save -f $tmpfile
        ^bash $tmpfile
        rm $tmpfile
    }}} --tags ["language manager", python, "version manager"] --reasons ["helps manage python installations"] |
    simple-add "python" {"windows": {"scoop": "python"}, "linux": {"custom": {|install: closure|
        use std [log]
        do $install 'pyenv'
        ^pyenv update
        ^pyenv latest --known '3.'
    }}} --tags [python, want, language] |
    simple-add "aria2" {"windows": {"scoop": "aria2"}} --tags [scoop] --reasons ["helps scoop download stuff better"] |
    simple-add "clink" {"windows": {"scoop": "clink"}} --tags [want] --reasons ["makes Windows' CMD easier to use", "enables starship in CMD"] |
    simple-add "git" {"windows": {"scoop": "git"}, "linux": {"apt-get": "git"}} --tags [want] --reasons ["revision control and source management", "downloading programs"] --links ["https://git-scm.com/docs"] |
    simple-add "7zip" {"windows": {"scoop": "7zip"}} --tags [scoop, exclude, auto] |
    simple-add "7zip19.00-helper" {"windows": {"scoop": "7zip19.00-helper"}} --tags [scoop, exclude, auto] |
    simple-add "audacity" {"windows": {"scoop": "audacity"}} --tags [rarely, large] |
    simple-add "caddy" {"windows": {"scoop": "caddy", "winget": "CaddyServer.Caddy"}, "linux": {"apt-get": "caddy"}} --tags [small, rarely] |
    simple-add "dark" {"windows": {"scoop": "dark"}} --tags [scoop, exclude, auto] |
    simple-add "tar" {"windows": {"custom": {|install: closure|
        use std [log]

        if (which tar | is-not-empty) {
            log info 'tar is already installed (on Windows 10 build 17063+)'
            return true
        }

        do $install 'scoop'
        run-external $nu.current-exe '-c' 'scoop install tar'
    }}, "linux": {"apt-get": "tar"}} --tags [small, want] |
    simple-add "dejavusansmono-nf" {"windows": {"scoop": "dejavusansmono-nf"}, "linux": {"custom": {|install: closure|
        use std [log]
        [] |
        append ( if (which 'xz' | is-empty) {'xz-utils'} else {null} ) |
        append ( if (which 'tar' | is-empty) {'tar'} else {null} ) |
        compact |
        if ($in | is-not-empty) {
            (
                ^sudo apt-get install
                    --no-install-recommends
                    --quiet
                    --assume-yes
                    --default-release stable
                    ...($in)
            )
        }
        # https://gist.github.com/matthewjberger/7dd7e079f282f8138a9dc3b045ebefa0?permalink_comment_id=3847557#gistcomment-3847557
        let asset = (
            http get --max-time 3 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' |
            get assets |
            where name =~ '(?i)DejaVuSansMono\.tar\.xz' |
            first
        )
        let tmpfile = (mktemp)
        http get $asset.browser_download_url | save -f $tmpfile
        let fonts_dir = ($env.HOME | path join '.local' 'share' 'fonts')
        ^tar -xJf $tmpfile -C $fonts_dir --wildcards '*.ttf'
        fc-cache -fv
    }}} --tags [want, fonts] |
    simple-add "duckdb" {"windows": {"scoop": "duckdb"}} --tags [small, undecided] --reasons ["cool database engine in same space as SQLite, but under really cool, active development by academics, with really cool features"] |
    simple-add "eget" {"windows": {"scoop": "eget"}, "android": {"custom": {|install: closure|
        let asset = (
            http get --max-time 3 'https://api.github.com/repos/zyedidia/eget/releases/latest' |
            get assets |
            where name =~ $'linux_(
                if $nu.os-info.arch != "aarch64" {
                    log warning "using 32-bit executable, I think?"
                    "arm"
                } else {
                    "arm64"
            })\.tar\.gz' |
            first
        )
        let tmpdir = (mktemp -d)
        let tmparchive = ($tmpdir | path join $asset.name)
        let tmpnames = ($tmpdir | path join 'filenames.txt')
        try {
            http get --max-time 10 $asset.browser_download_url |
            save -f $tmparchive

            echo $'($asset.name | str replace --regex '\.tar\.gz$' '')/eget' |
            save -f $tmpnames

            ^tar --extract --overwrite $'--directory=("~/.local/bin" | path expand)' $'--file=($tmparchive)' --gzip --strip-components=1 $'--files-from=($tmpnames)'
        } catch {|e| log error $e.msg}
        rm -r $tmpdir
    }}} --tags [want, "package manager"] --reasons ["makes installing stuff from GitHub releases much easier"] --links ["https://github.com/zyedidia/eget?tab=readme-ov-file#eget-easy-pre-built-binary-installation"] |
    simple-add "fd" {"windows": {"scoop": "fd"}} --search-help [find, rust] --tags [want, small] |
    simple-add "ffmpeg" {"windows": {"scoop": "ffmpeg"}} --tags [large, yt-dlp] |
    simple-add "filezilla" {"windows": {"scoop": "filezilla"}} --tags [filezilla] |
    simple-add "fontforge" {"windows": {"scoop": "fontforge"}} --tags [rarely] |
    simple-add "foobar2000" {"windows": {"scoop": "foobar2000"}} --tags [why_even] --reasons ["has an ABX plugin that makes comparing two songs to see which one is encoded in a better qualitymuch easier"] |
    simple-add "freac" {"windows": {"scoop": "freac"}} --tags [why_even] |
    simple-add "fvim" {"windows": {"scoop": "fvim"}} --tags [why_even] --reasons ["at one point, before neovide, was really good with the Comic Code font"] |
    simple-add "gifsicle" {"windows": {"scoop": "gifsicle"}} --tags [small, rarely] --reasons ["used by other programs like Screen2Gif to minify gifs"] |
    simple-add "gifski" {"windows": {"scoop": "gifski"}} --tags [small, rarely] --reasons ["used by other programs like Screen2Gif to minify gifs"] |
    simple-add "gnupg" {"windows": {"scoop": "gnupg"}} --tags [want, small] |
    simple-add "handbrake" {"windows": {"scoop": "handbrake"}} --tags [rarely, large] |
    simple-add "hashcat" {"windows": {"scoop": "hashcat"}} --tags [why_even] --reasons ["tries to make cracking hashes and guessing passwords easier"] |
    simple-add "imageglass" {"windows": {"scoop": "imageglass"}} --search-help [avif, "av1", iPhone, picture] --tags [rarely] --reasons ["nicer image viewer", "can display and convert iPhone .avif images for free"] |
    simple-add "inkscape" {"windows": {"scoop": "inkscape"}} --tags [large] |
    simple-add "innounp" {"windows": {"scoop": "innounp"}} --tags [scoop, exclude, auto] |
    simple-add "jq" {"windows": {"scoop": "jq"}} --tags [small] |
    simple-add "keepass" {"windows": {"scoop": "keepass"}} --tags [want, keepass] |
    simple-add "keepass-plugin-keetraytotp" {"windows": {"scoop": "keepass-plugin-keetraytotp"}} --tags [want, keepass] |
    simple-add "keepass-plugin-readable-passphrase" {"windows": {"scoop": "keepass-plugin-readable-passphrase"}} --tags [want, keepass] |
    simple-add "libreoffice" {"windows": {"scoop": "libreoffice"}} --tags [large] --reasons ["libreoffice draw is good at editing PDFs in complex ways"] |
    simple-add "libxml2" {"windows": {"scoop": "libxml2"}} --tags [why_even] --reasons ["was used for rendering DocBook documents, like rendering the .epub of PostgreSQL documentation"] |
    simple-add "love" {"windows": {"scoop": "love"}} --tags [small, rarely, game, fun, lua] --reasons ["small game framework for lua that I've never really gotten to use"] |
    simple-add "luajit" {"windows": {"scoop": "luajit"}} --tags [small, language, lua] --reasons ["fast lua runtime"] |
    simple-add "mariadb" {"windows": {"scoop": "mariadb"}} --tags [large, rarely] |
    simple-add "mpv" {"windows": {"scoop": "mpv"}} --tags [want] --reasons ["has fewer visual \"glitches\" than vlc, and plays as wide a variety of media, including HEVC/h.265 for free"] |
    simple-add "neovide" {"windows": {"scoop": "neovide"}, "linux": {"eget": "neovide/neovide"}} --tags [want, neovim] |
    simple-add "neovim" {"windows": {"scoop": "neovim"}, "linux": {"custom": {|install: closure|
        do $install 'asdf'
        run-external $nu.current-exe '-l' '-c' 'asdf plugin add neovim'
        run-external $nu.current-exe '-l' '-c' 'asdf install neovim stable'
        run-external $nu.current-exe '-l' '-c' 'asdf global neovim stable'
    }}} --tags [essential] |
    simple-add "notepadplusplus" {"windows": {"scoop": "notepadplusplus"}} --tags [small, rarely] |
    simple-add "nu" {"windows": {"scoop": "nu"}, "linux": {"eget": "nushell/nushell"}, "android": {"pkg": "nushell"}} --tags [essential, small] |
    simple-add "obs-studio" {"windows": {"scoop": "obs-studio"}} --tags [large] |
    simple-add "pandoc" {"windows": {"scoop": "pandoc"}} --tags [small, rarely] --reasons ["really good at converting one document format to another"] |
    simple-add "peazip" {"windows": {"scoop": "peazip"}} --tags [want] --reasons ["much nicer interface than 7zip, can do all the same stuff"] |
    simple-add "picard" {"windows": {"scoop": "picard"}} --search-help [musicbrainz] --tags [large, rarely, music] --reasons ["makes organizing and tagging songs, and wrangling metadata, much easier"] |
    simple-add "postgresql" {"windows": {"scoop": "postgresql"}} --tags [large, rarely] |
    simple-add "pwsh" {"windows": {"scoop": "pwsh"}} --tags [want, rarely] --reasons ["better powershell"] |
    simple-add "rclone" {"windows": {"scoop": "rclone"}} --tags [small, rarely, want] --reasons ["makes copying files between the cloud and locally much, much easier"] |
    simple-add "ripgrep" {"windows": {"scoop": "ripgrep"}, "linux": {"eget": "BurntSushi/ripgrep"}} --search-help [rg] --tags [small, want] --reasons ["cross-platform, faster grep"] |
    simple-add "rufus" {"windows": {"scoop": "rufus"}} --tags [small, want, gui] --reasons ["makes creating bootable flashdrives much, much easier"] |
    simple-add "screentogif" {"windows": {"scoop": "screentogif"}} --tags [gui, rarely] --reasons ["makes screen recording quite quick and simple"] |
    simple-add "shellcheck" {"windows": {"scoop": "shellcheck"}} --tags [language, small, rarely, tooling, shell, sh] --reasons ["lints POSIX shell scripts"] |
    simple-add "sqlite" {"windows": {"scoop": "sqlite"}} --tags [small, want, language] --reasons ["beloved database engine that makes using SQL a breeze", "sqlean is better if I can get it"] |
    simple-add "sqlitebrowser" {"windows": {"scoop": "sqlitebrowser"}} --tags [why_even, exclude] --reasons ["visualizes a sqlite database, but I can do that with the sqlite cli"] |
    simple-add "starship" {"windows": {"scoop": "starship"}} --tags [want, style] --reasons ["makes my shell prompt cross-platform, cross-shell, and nice"] |
    simple-add "stylua" {"windows": {"scoop": "stylua"}} --tags [small, tooling, lua] --reasons ["auto-formatting lua"] |
    simple-add "taplo" {"windows": {"scoop": "taplo"}} --tags [small, tooling, toml] --reasons ["I think it can lint TOML files? I think I installed it for conform.nvim"] |
    simple-add "transmission" {"windows": {"scoop": "transmission"}} --tags [small, rarely] --reasons ["my preferred (bit)torrent client"] |
    simple-add "tree-sitter" {"windows": {"scoop": "tree-sitter"}} --tags [want] --reasons ["works with neovim to make highlighting and editing much nicer"] |
    simple-add "upx" {"windows": {"scoop": "upx"}} --tags [small, rarely, tooling] --reasons ["free, open source executable packer, to make executables as small as possible"] |
    simple-add "vlc" {"windows": {"scoop": "vlc"}} --tags [want, small] --reasons ["beloved media player", "can do lots of cool tricks"] |
    simple-add "windirstat" {"windows": {"scoop": "windirstat"}} --tags [want, small] --reasons ["visualizes hard drive allocation by file size", "makes it much, much easier to find large files taking up hard drive space and delete them"] |
    simple-add "wsl-ssh-pageant" {"windows": {"scoop": "wsl-ssh-pageant"}} --tags [want, gnupg, windows] --reasons ["makes it possible to use gnupg as an ssh agent on Windows"] |
    simple-add "xmplay" {"windows": {"scoop": "xmplay"}} --tags [small, gui, music, rarely] --reasons ["has a cool rabbit hole visualizer plugin, and can play MOD files"] |
    simple-add "snap" {"linux": {"custom": {|install: closure|
        do $install 'apt-get'
        sudo apt-get install --no-install-recommends --assume-yes --default-release stable snapd
        try {snap install core} catch {snap refresh core}
}}} --tags ["package manager"] --reasons ["currently used to install zig on linux"] |
    simple-add "zig" {"windows": {"scoop": "zig"}, "linux": {"custom": {|install: closure|
        # https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager#ubuntu-snap
        do $install 'snap'
        snap install zig --classic --beta
    }}} --tags [language, want, compiler, zig] --reasons ["cool language", "acts as my cross-platform C compiler"] |
    simple-add "zls" {"windows": {"scoop": "zls"}} --tags [tooling, zig] --reasons ["official zig language server"] |
    simple-add "zstd" {"windows": {"scoop": "zstd"}, "linux": {"apt-get": "zstd"}} --tags [small] --reasons ["allows me to get more compression out of zstd than PeaZip"] |
    simple-add "mullvadvpn" {"windows": {"winget": "MullvadVPN.MullvadVPN"}} --tags [small, vpn] --reasons ["beloved, occasionally used vpn client"] |
    simple-add "Microsoft.VisualStudio.2022.BuildTools" {"windows": {"winget": "Microsoft.VisualStudio.2022.BuildTools"}} --tags [large, compiler, rust, tooling, C, C++] --reasons ["used by rust to compile/link stuff on Windows"] |
    simple-add "discord" {"windows": {"winget": "Discord.Discord"}} --tags [large, gui, chat] |
    simple-add "Google.Chrome.EXE" {"windows": {"winget": "Google.Chrome.EXE"}} --tags [large, browser] |
    simple-add "imagemagick" {"windows": {"winget": "ImageMagick.ImageMagick"}} --tags [large] --reasons ["can convert any image format into any image format", "cli program for manipulating images", "use to use it for generating art, like my desktop background and phone lockscreen"] |
    simple-add "Microsoft.Edge" {"windows": {"winget": "Microsoft.Edge"}} --tags [exclude, large, system] |
    simple-add "Microsoft.EdgeWebView2Runtime" {"windows": {"winget": "Microsoft.EdgeWebView2Runtime"}} --tags [system, exclude] |
    simple-add "Microsoft.AppInstaller" {"windows": {"winget": "Microsoft.AppInstaller"}} --tags [want, winget] --reasons ["provides winget"] |
    simple-add "Microsoft.UI.Xaml.2.7" {"windows": {"winget": "Microsoft.UI.Xaml.2.7"}} --tags [exclude] |
    simple-add "Microsoft.UI.Xaml.2.8" {"windows": {"winget": "Microsoft.UI.Xaml.2.8"}} --tags [exclude] |
    simple-add "Microsoft.VCLibs.Desktop.14" {"windows": {"winget": "Microsoft.VCLibs.Desktop.14"}} --tags [exclude] |
    simple-add "Microsoft.WindowsTerminal" {"windows": {"winget": "Microsoft.WindowsTerminal"}} --tags [want, gui, windows] --reasons ["use to be my favorite terminal emulator before neovide+neovim"] |
    simple-add "Microsoft.Teams.Free" {"windows": {"winget": "Microsoft.Teams.Free"}} --tags [exclude, remove] |
    simple-add "firefox" {"windows": {"winget": "Mozilla.Firefox"}, "linux": {"custom": {|install: closure|
        use std [log]
        do $install 'gnupg2'

        # https://support.mozilla.org/en-US/kb/install-firefox-linux#w_install-firefox-deb-package-for-debian-based-distributions
        log info "Create a directory to store APT repository keys if it doesn't exist"
        ^sudo install -d -m 0755 /etc/apt/keyrings

        log info "Import the Mozilla APT repository signing key"
        let tmpfile = (mktemp)
        http get 'https://packages.mozilla.org/apt/repo-signing-key.gpg' | save -f $tmpfile
        let target = '/etc/apt/keyrings/packages.mozilla.org.asc'
        ^sudo cp $tmpfile $target
        rm $tmpfile
        ^sudo chmod u=rw,g=r,o=r $target

        log info 'check fingerprint'
        ^gpg -n -q --import --import-options import-show $target |
        ^awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'

        log info 'Next, add the Mozilla APT repository to your sources list'
        sudo cp ~/projects/dotfiles/debian/etc/apt/sources.list.d/mozilla.sources /etc/apt/sources.list.d/mozilla.sources

        log info 'Configure APT to prioritize packages from the Mozilla repository'
        sudo cp ~/projects/dotfiles/debian/etc/apt/preferences.d/mozilla /etc/apt/preferences.d/mozilla

        log info 'Update your package list and install the Firefox .deb package'
        ^sudo apt-get update --assume-yes
        ^sudo apt-get install --no-install-recommends --quiet --assume-yes --default-release stable firefox
    }}} --tags [want, large] --reasons ["beloved browser"] |
    simple-add "Microsoft.OneDrive" {"windows": {"winget": "Microsoft.OneDrive"}} --tags [want, system] --reasons ["what I use to sync all my files cross-platform"] |
    simple-add "rustup" {"windows": {"winget": "Rustlang.Rustup"}} --tags [tooling, language, rust] --reasons ["rust's main way of managing compiler versions"] |
    simple-add "Valve.Steam" {"windows": {"winget": "Valve.Steam"}} --tags [gui, games, large] |
    simple-add "DigitalExtremes.Warframe" {"windows": {"winget": "DigitalExtremes.Warframe"}} --tags [exclude] |
    simple-add "universalmediaserver" {"windows": {"winget": "UniversalMediaServer.UniversalMediaServer"}} --tags [large] --reasons ["does all the local network hosting and live, on-the-fly transcoding of videos really easy", "upnp media server compatible with my Roku TV's Roku Media Player"] |
    simple-add "zint" {"windows": {"winget": "Zint.Zint"}} --tags [small, gui, windows, barcodes] --reasons ["beloved barcode creation studio"] |
    simple-add "zoom" {"windows": {"winget": "Zoom.Zoom"}} --tags [office] |
    simple-add "libjpeg-turbo.libjpeg-turbo.VC" {"windows": {"winget": "libjpeg-turbo.libjpeg-turbo.VC"}} --tags [exclude, auto] |
    simple-add "Microsoft.VCRedist.2013.x64" {"windows": {"winget": "Microsoft.VCRedist.2013.x64"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2010.x64" {"windows": {"winget": "Microsoft.VCRedist.2010.x64"}} --tags [exclude] |
    simple-add "GlavSoft.TightVNC" {"windows": {"winget": "GlavSoft.TightVNC"}} --tags [want] --reasons ["my preferred VNC remote desktop solution", "I use the RealVNC app on Android an iOS"] |
    simple-add "Microsoft.VCRedist.2012.x86" {"windows": {"winget": "Microsoft.VCRedist.2012.x86"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2015+.x86" {"windows": {"winget": "Microsoft.VCRedist.2015+.x86"}} --tags [exclude] |
    simple-add "Telegram.TelegramDesktop" {"windows": {"winget": "Telegram.TelegramDesktop"}} --tags [chat, gui, rarely] --reasons ["desktop chat client, but I can also use the web app"] |
    simple-add "Microsoft.DotNet.DesktopRuntime.6" {"windows": {"winget": "Microsoft.DotNet.DesktopRuntime.6"}} --tags [exclude] |
    simple-add "Microsoft.CLRTypesSQLServer.2019" {"windows": {"winget": "Microsoft.CLRTypesSQLServer.2019"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2008.x64" {"windows": {"winget": "Microsoft.VCRedist.2008.x64"}} --tags [exclude] |
    simple-add "PlayStation.DualSenseFWUpdater" {"windows": {"winget": "PlayStation.DualSenseFWUpdater"}} --tags [windows, rarely] --reasons ["DualSense / DualShock5 / DS5 firmware updating tool"] |
    simple-add "ViGEm.ViGEmBus" {"windows": {"winget": "ViGEm.ViGEmBus"}} --tags [games, windows, "ds4windows"] --reasons ["used by ds4windows"] |
    simple-add "ElectronicArts.EADesktop" {"windows": {"winget": "ElectronicArts.EADesktop"}} --tags [exclude, auto] |
    simple-add "Microsoft.VCRedist.2008.x86" {"windows": {"winget": "Microsoft.VCRedist.2008.x86"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2013.x86" {"windows": {"winget": "Microsoft.VCRedist.2013.x86"}} --tags [exclude] |
    simple-add "Nvidia.PhysXLegacy" {"windows": {"winget": "Nvidia.PhysXLegacy"}} --tags [exclude] |
    simple-add "EpicGames.EpicGamesLauncher" {"windows": {"winget": "EpicGames.EpicGamesLauncher"}} --tags [games, large] |
    simple-add "Mozilla.VPN" {"windows": {"winget": "Mozilla.VPN"}} --tags [rarely, vpn] --reasons ["used to use this VPN for a bit; when I used it, they were using Mullvad as the provider"] |
    simple-add "winfsp" {"windows": {"winget": "WinFsp.WinFsp"}} --tags ["not sure", windows] --reasons ["I think another program required it"] --links ["https://github.com/winfsp/winfsp"] |
    simple-add "Microsoft.VCRedist.2010.x86" {"windows": {"winget": "Microsoft.VCRedist.2010.x86"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2015+.x64" {"windows": {"winget": "Microsoft.VCRedist.2015+.x64"}} --tags [exclude] |
    simple-add "Microsoft.VCRedist.2012.x64" {"windows": {"winget": "Microsoft.VCRedist.2012.x64"}} --tags [exclude] |
    simple-add "black" {"windows": {"pipx": "black"}} --tags [tooling, python] --reasons ["python auto formatter"] |
    simple-add "build" {"windows": {"pipx": "build"}} --tags [rarely, tooling, python] --reasons ["used for building some distributions"] |
    simple-add "certbot" {"windows": {"pipx": "certbot"}} --tags [webserver, ssl, rarely] --reasons ["makes getting a letsencrypt certificate much, much easier", "caddy is better, as it handles that acme protocol itself, and is a very flexible webserver"] |
    simple-add "commitizen" {"windows": {"pipx": "commitizen"}} --tags [rarely, tooling] --reasons ["helps me remember how to format git commit messages"] |
    simple-add "httpie" {"windows": {"pipx": "httpie"}} --tags [curl] --reasons ["much nicer to use, but slightly less full-featured than curl (I've never hit those limits, thought)"] |
    simple-add "isort" {"windows": {"pipx": "isort"}} --tags [old, python, tooling] --reasons ["auto code formatter specifically for imports", "now I use ruff or usort", "last time I checked, this didn't use a parser, just regex, and that scared me"] |
    simple-add "mypy" {"windows": {"pipx": "mypy"}} --tags [python, tooling, language] --reasons ["python type checker", "I basically don't write Python without it"] |
    simple-add "poetry" {"windows": {"pipx": "poetry"}} --tags [old, python, tooling] --reasons ["dependency and package/project manager for Python"] --links ["https://github.com/python-poetry/poetry/", "https://python-poetry.org/"] |
    simple-add "py-spy" {"windows": {"pipx": "py-spy"}} --tags [python, tooling] --reasons ["python performance monitoring tool that can hook into a running Python process to produce a flamegraph, or provide a top-like interface to watch which codepaths are being run the most frequently, and/or spending the most time being run", "can help uncover deadlocks without having to use gdb"] |
    simple-add "pyclip" {"windows": {"pipx": "pyclip"}} --tags [want, clipboard] --reasons ["makes working with the clipboard consistent across platforms; even Windows"] |
    simple-add "pygount" {"windows": {"pipx": "pygount"}} --tags [small, rarely, python, tooling] --reasons ["python LOCs (lines of code) reporting tool (recognizes languages other than Python"] |
    simple-add "pylint" {"windows": {"pipx": "pylint"}} --tags [python, tooling] --reasons ["linting for Python", "ruff is cirrently doing a great job", "detects the most things"] |
    simple-add "pytest" {"windows": {"custom": {|install: closure|
        do $install 'pipx'
        ^python -X utf8 -m pipx install pytest
        ^python -X utf8 -m pipx inject pytest "pytest-cov"
        ^python -X utf8 -m pipx inject pytest "pytest-subtests"
        ^python -X utf8 -m pipx inject pytest "mypy"
        ^python -X utf8 -m pipx inject pytest "pylint"
    }}} --tags [python, tooling] --reasons ["incredible python testing framework", indispensible] |
    simple-add "ruff" {"windows": {"pipx": "ruff"}} --tags [python, tooling] --reasons ["auto formats and lints python code incredibly quickly"] |
    simple-add "ruff-lsp" {"windows": {"pipx": "ruff-lsp"}} --tags [python, tooling, neovim] --reasons ["makes ruff easy to use with neovim; used by conform.nvim"] |
    simple-add "sqlfluff" {"windows": {"pipx": "sqlfluff"}} --tags [sql, tooling] --reasons ["linting for sql", "don't know how to use/configure it"] |
    simple-add "tox" {"windows": {"pipx": "tox"}} --tags [python, tooling] --reasons ["beloved test runner", "makes it super nice to have very isolated test environments, and can run the tests across multiple versions of Python"] |
    simple-add "twine" {"windows": {"pipx": "twine"}} --tags [small, python, tooling] --reasons ["was the blessed tool to upload packages to PyPI"] |
    simple-add "usort" {"windows": {"pipx": "usort"}} --tags [python, tooling] --reasons ["large-corporation-made replacement for isort"] |
    simple-add "xonsh" {"windows": {"pipx": "xonsh[full]"}} --tags [python, shell, environment, rarely] --reasons ["beloved cross-platform shell; extremely friendly to python"] |
    simple-add "youtube-dl" {"windows": {"pipx": "youtube-dl"}} --tags [old, small] --reasons ["used to be my favorite (youtube) video downloader before yt-dlp"] |
    simple-add "yt-dlp" {"windows": {"pipx": "yt-dlp"}} --tags [small, want, yt-dlp] --reasons ["really, really good (youtube) video downloader based on youtube-dl"] |
    simple-add "exiv2" {"linux": {"apt-get": "exiv2"}} --search-help [picture] --tags [small] --reasons ["my favorite tool for reading and manipulating EXIF data in images"] |
    simple-add "exiftool" {"windows": {"scoop": "exiftool", "winget": "exiftool"}, "linux": {"apt-get": "exiftool"}} --search-help [picture] --tags [small] --reasons ["popular EXIF image metadata manipulation program"] |
    simple-add "sqlean" {"windows": {"eget": "nalgeon/sqlite"}} --tags [small, want] --reasons ["fantastic recompile of SQLite to include really useful extensions"] --links ["https://github.com/nalgeon/sqlite"] |
    simple-add "bat" {"windows": {"scoop": "bat"}} --tags [small] --reasons ["like cat, but better"] --links ["https://github.com/sharkdp/bat"] |
    simple-add "ncspot" {"windows": {"scoop": "ncspot", "winget": "hrkfdn.ncspot"}} --tags [small, music] --reasons ["cli spotify client that works really well"] --links ["https://github.com/hrkfdn/ncspot"] |
    simple-add "sops" {"windows": {"custom": {||
                ^eget getsops/sops
                do {
                    open $env.EGET_CONFIG | get global.target | cd $in
                    glob 'sops*.exe' | first | mv $in 'sops.exe'
                }
            }, "scoop": "sops"}} --tags [encryption, small] --reasons ["maintained, accessible usage of Shamir's Secret Sharing Algorithm (SSSS)"] --links ["https://github.com/getsops/sops"] |
    simple-add "age" {"windows": {"scoop": "age"}, "linux": {"eget": "FiloSottile/age"}} --tags [encryption, small] --reasons ["very simply file encryption"] --links ["https://github.com/FiloSottile/age"] |
    simple-add "fzf" {"windows": {"scoop": "fzf"}} --tags [small, rarely] --reasons ["very simple interactive fuzzy finder that can be used from other scripts"] --links ["https://github.com/junegunn/fzf"] |
    simple-add "nvr" {"windows": {"pipx": "neovim-remote"}} --tags [want, small, neovim] --reasons ["allows opening a file from within a :terminal session, inside the editor that :terminal is running within, instead of opening a nested editor", "will be essential until --remote-wait is natively supported by neovim: https://neovim.io/doc/user/remote.html#E5600"] --links ["https://github.com/mhinz/neovim-remote"] |
    simple-add "nvm" {"windows": {"scoop": "nvm"}} --tags [javascript, tooling, rarely] --reasons ["helps install various js-based tooling", "nvm4win may be deprecated soon in favor of Runtime"] --links ["https://github.com/coreybutler/nvm-windows/discussions/565#discussioncomment-58112", "https://github.com/nvm-sh/nvm"] |
    simple-add "fnm" {"windows": {"scoop": "fnm"}} --tags [javascript, tooling, rarely] --reasons ["cross-platform node version manager"] --links ["https://github.com/Schniz/fnm"] |
    simple-add "node" {"windows": {"custom": {|install: closure|
        do $install 'fnm'
        ^fnm install --lts
        ^fnm default lts-latest

        use std [log]
        log info "use a command like the folowing to find where node is installed:\nfnm exec --using=default nu -c '$env.PATH | first | path join \"node.exe\"'"
    }}} --tags [javascript, tooling, large, rarely] --reasons ["helps install various js-based tooling"] |
    simple-add "protoc" {"windows": {"scoop": "protobuf"}} --reasons ["dependency for compiling atuin v18.3 (and maybe up?) on Windows"] |
    simple-add "atuin" {"windows": {"custom": {|install: closure|
        do $install 'protoc'
        do $install 'cargo'
        ^cargo install --all-features --bins --keep-going 'atuin'
    }}, "linux": {"custom": {|install: closure|
        let tmpfile = (mktemp)
        http get --redirect-mode 'follow' --max-time 3 'https://setup.atuin.sh' | save -f $tmpfile
        ^sh $tmpfile
        rm $tmpfile
    }}} --tags [cli, want, history] --reasons ["syncs my command history across platforms and computers"] |
    simple-add "fennel" {"windows": {"custom": {|install: closure|
        do $install 'luajit'
        http get 'https://fennel-lang.org/downloads/fennel-' |
        save -f ~/.local/bin/fennel
    }}} --tags [small, lua, language, fennel, compiler, undecided] --reasons ["cool, type-safe language that transpiles to Lua"] --links ["https://fennel-lang.org"] |
    simple-add "janet" {"android": {"custom": {|install: closure|
        let old_dir = ($env.PWD)
        ^pkg install --assume-yes libandroid-spawn binutils llvm
        let tmpdir = (mktemp --directory --tmpdir)
        let janet_json = (http get 'https://api.github.com/repos/janet-lang/janet/releases/latest')
        let tag = ($janet_json | get tag_name)
        cd $tmpdir
        git clone --depth 1 --single-branch --branch $tag 'https://github.com/janet-lang/janet.git' ./janet
        git clone --depth 1 --single-branch 'https://github.com/janet-lang/jpm.git' ./jpm
        cd ./janet
        $env.AR = 'llvm-ar'
        ^make -j
        make install
        cd ($tmpdir | path join 'jpm')
        ^janet bootstrap.janet
        cd $old_dir
        rm -r $tmpdir
    }}, "windows": {"custom": {|install: closure|
        # do $install "Microsoft.VisualStudio.2022.BuildTools"

        use std [log]
        use utils.nu [powershell-safe]

        let janet_json = (http get 'https://api.github.com/repos/janet-lang/janet/releases/latest')
        let tag = ($janet_json | get tag_name)
        let tmpdir = (mktemp --directory --tmpdir)
        print $'tmpdir -> ($tmpdir)'
        let wix_zip = ($tmpdir | path join 'wix314-binaries.zip')
        let wix_dir = ($tmpdir | path join 'wix')
        log info 'downloading wix toolset'
        http get 'https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip' | save -f $wix_zip

        log info 'unpacking wix toolset'
        [($wix_zip), ($wix_dir)] |
        str join (char nul) |
        powershell-safe -c '$in = ($Input -split [char]0x0); Expand-Archive -LiteralPath $in[0] -DestinationPath $in[1] -Force'

        git clone --depth 1 --single-branch --branch $tag 'https://github.com/janet-lang/janet.git' ($tmpdir | path join 'janet')
        git clone --depth 1 --single-branch 'https://github.com/janet-lang/jpm.git' ($tmpdir | path join 'jpm')

        log info 'building janet'
        let build_dir = (
            run-external (
                $env |
                get 'PROGRAMFILES(X86)' |
                path join 'Microsoft Visual Studio' 'Installer' 'vswhere.exe'
            ) '-format' 'json' '-utf8' '-products' '*' '-latest' |
            from json |
            into record |
            get installationPath
        )
        cd $build_dir
        let vcvars = $'call ("VC" | path join "Auxiliary" "build" "vcvars64.bat")'
        with-env {PATH: ($env.PATH | append $wix_dir)} {
            cmd /c $'($vcvars) && cd ($tmpdir) && cd janet && call build_win.bat && call build_win.bat test && call build_win.bat dist'
        }

        log info 'installing janet'
        msiexec /passive /norestart /i (
            $tmpdir |
            path join 'janet' |
            do {
                cd $in
                glob '*.msi' |
                first
            }
        )
        cd ($tmpdir | path join 'jpm')
        let janet_bin_dir = ($env.LOCALAPPDATA | path join 'Apps' 'Janet' 'bin')
        if ($janet_bin_dir | path exists) {
            log info $'janet installed to -> ($janet_bin_dir)'
            if ($janet_bin_dir not-in $env.PATH) {
                $env.PATH |
                append $janet_bin_dir |
                append ('~/scoop' | path expand | path join 'apps' 'git' 'current' 'mingw64' 'libexec' 'git-core') | # https://stackoverflow.com/a/50833818
                uniq |
                do $env.ENV_CONVERSIONS.PATH.to_string $in |
                powershell-safe -c '$in = $Input; [Environment]::SetEnvironmentVariable("Path", $in, "User")'
            }
            $env.PATH = ($env.PATH | append $janet_bin_dir)
            $env.JANET_PATH = ($janet_bin_dir | path dirname | path join 'Library')
            log info $'setting JANET_PATH to -> ($env.JANET_PATH)'
            mkdir $env.JANET_PATH
            run-external ($janet_bin_dir | path join 'janet.exe') 'bootstrap.janet'
        } else {
            log warning 'the janet installer ran, but I do not know where it was installed to'
            log error 'jpm not installed, have to install manually'
        }
        cd ~
        rm -r $tmpdir
    }}} --tags [undecided, small, language, janet] --reasons ["embeddable language that has it's own package manager, is <2M, and has some cool features"] --links ["https://janet-lang.org"] |
    simple-add "hererocks" {"windows": {"pipx": "git+https://github.com/luarocks/hererocks"}} --tags [small, language, lua, moonscript, tooling, luarocks, requires_compiler] --reasons ["helps to install lua and luarocks"] --links ["https://github.com/luarocks/hererocks"] |
    simple-add "lua51" {"windows": {"custom": {|install: closure|
        do $install 'scoop'
        ^scoop bucket add versions
        ^scoop install lua51
}}} --tags [small, language, lua, tooling, lazy.nvim] --reasons ["needed by lazy.nvim"] |
    simple-add "luarocks" {"windows": {"custom": {|install: closure|
        # do $install "Microsoft.VisualStudio.2022.BuildTools"
        do $install 'lua51'
        do $install 'hererocks'
        use std [log]
        use utils.nu [powershell-safe]

        # put it in the place lazy.nvim expects it, because why not
        let hererocks_dir = ($env.LOCALAPPDATA | path join 'nvim-data' 'lazy-data' 'hererocks')
        let cache_dir = ($env.LOCALAPPDATA | path join 'HereRocks' 'Cache')
        let downloads = ($cache_dir | path join 'downloads')
        let builds = ($cache_dir | path join 'builds')
        mkdir $hererocks_dir $downloads $builds

        ^hererocks $hererocks_dir --luarocks 'latest' --lua 'latest' --patch --target 'vs' --downloads $downloads --builds $builds --verbose

        let bin_dir = ($hererocks_dir | path join 'bin')
        if ($bin_dir | path exists) {
            log info $'luarocks installed to -> ($bin_dir)'
            if ($bin_dir not-in $env.PATH) {
                powershell-safe -c '[Environment]::GetEnvironmentVariable("Path", "User")' |
                get stdout |
                do $env.ENV_CONVERSIONS.PATH.from_string $in |
                append $env.PATH |
                prepend $bin_dir |
                uniq |
                do $env.ENV_CONVERSIONS.PATH.to_string $in |
                powershell-safe -c '$in = $Input; [Environment]::SetEnvironmentVariable("Path", $in, "User")'
            }
            $env.PATH = ($env.PATH | prepend $bin_dir)
        }

}}} --tags [small, language, lua, moonscript, tooling, luarocks, requires_compiler] --reasons ["package manager for Lua and moonscript, and can be used by lazy.nvim"] --links ["https://luarocks.org/"] |
    simple-add "curl" {"windows": {"scoop": "curl"}, "linux": {"apt-get": "curl"}} --tags ["download", "small", "want"] --reasons ["quite the ubiquitous internet protocol tool"] |
    simple-add "asdf" {"linux": {"custom": {|install: closure|
        do $install 'git'
        do $install 'curl'

        git clone --single-branch --branch v0.14.1 'https://github.com/asdf-vm/asdf.git' ~/.asdf
        run-external $nu.current-exe '-l' '-c' 'asdf update'
    }}} --tags ["version manager", "language manager"] --reasons ["currently used for managing neovim installations"] |
    simple-add "chezmoi" {"windows": {"eget": "twpayne/chezmoi"}} --tags [dotfiles, essential] --reasons ["dotfile manager that's been around for a while"] --links ["https://chezmoi.io"] |
    simple-add "kanata" {"windows": {"eget": "jtroo/kanata"}, "linux": {"custom": {|install: closure|
        use std [log]

        log info "following the instructions from:\nhttps://github.com/jtroo/kanata/blob/main/docs/setup-linux.md"

        let user = (id -un)
        log info $'using ($user) as username'
        let input_exists = (
            do {getent group input} |
            complete |
            get exit_code |
            ($in == 0)
        )
        if not $input_exists {
            log info 'group "input" does not exist; creating it'
            sudo addgroup --system input
        } else {log info 'group "input" exists'}
        let uinput_exists = (
            do {getend group uinput} |
            complete |
            get exit_code |
            ($in == 0)
        )
        if not $uinput_exists {
            log info 'group "uinput" does not exist; creating it'
            sudo addgroup --system uinput
        } else {log info 'group "uinput" exists'}
        if not (
            getent group input |
            parse '{group}:{something}:{gid}:{user}' |
            get user |
            split row ',' |
            any {|it| $it == $user}
        ) {
            log info $'($user) is not a member of group "input"; adding'
            sudo usermod -a -G input $user
        } else {log info $'($user) is already a member of group "input"'}
        if not (
            getent group uinput |
            parse '{group}:{something}:{gid}:{user}' |
            get user |
            split row ',' |
            any {|it| $it == $user}
        ) {
            log info $'($user) is not a member of group "uinput"; adding'
            sudo usermod -a -G uinput $user
        } else {log info $'($user) is already a member of group "uinput"'}
        let $kanata_rules = '/etc/udev/rules.d/01-kanata.rules'
        if not ($kanata_rules | path exists) {
            log info $'creating udev rules for kanata at ($kanata_rules)'
            sudo cp ($env.HOME | path join 'projects' 'dotfiles' 'dot_config' 'kanata' '01-kanata.rules') $kanata_rules
        } else {log info $'udev rules for kanata already exist at ($kanata_rules)'}
        log info 'reloading udev rules and triggering(???) them'
        sudo udevadm control --reload-rules
        sudo udevadm trigger

        log info 'downloading kanata'
        do $install 'eget'
        eget 'jtroo/kanata'

        log info 'starting kanata and setting to autostart'
        ^systemctl --user enable kanata.service
        try {
            ^systemctl --user restart kanata.service
        } catch {
            log info 'may have to log in and out again to get the group membership and such to register'
        }
    }}} --tags [small, keyboard, want] --reasons ["does keyboard mapping like swapping CapsLock and Control in software"] --links ["https://github.com/jtroo/kanata"] |
    validate-data
}
