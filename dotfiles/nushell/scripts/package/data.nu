# use $'($nu.default-config-dir)/scripts/package/manager.nu'

const platform = ($nu.os-info.name)

def "get c-p" [cell_path: list<string>, ...rest] {
    let source = ($in)
    (
        $rest
        | default []
        | prepend [$cell_path]
        | each {|it|
            $source | get (
                $it
                | wrap value
                | insert optional false
                | into cell-path
            )
        }
    )
}

# add a package to the package metadata file (use `package path` to list it)
export def add [
    # the package manager-independent identifier
    name: string,
    # a record of the platforms it can be installed on, and the package
    # managers and identifiers that can be used to install it
    install: record,
    # these are used in searching, to help find a package
    --search-help: list<string>,
    # used in sorting, selecting, and searching
    --tags: list<string>,
    # explanations and notes about the packages
    --reasons: list<string>,
    # URLs to repositories and documentation
    --links: list<string>,
] {
    # `default` here will absorb the piped input and return that instead of the
    # empty structure
    default {} |
        # I'm inserting into a record so that any calls to `add` that have a
        # duplicate package name will produce an error at the command that
        # tries to insert it
        insert ($name) {
        'install': $install, 
        'search_help': ($search_help | default []),
        'tags': ($tags | default []),
        'reasons': ($reasons | default []),
        'links': ($links | default []),
    }

}

# take a record of package data and separate the custom closures, replacing
# them with the string representation of their source code
def "separate-customs" [] {
    # the intended resulting structure is something like
    # {
    #     'customs': {
    #         'platform_name1': {
    #             'package_name1': {|| print 'install package_name1 on platform_name1'},
    #         },
    #         'platform_name2': {
    #             'package_name1': {|| print 'install package_name1 on platform_name2'},
    #         },
    #     },
    #     'data': {
    #         'package_name1': {
    #             'install': {
    #                 'platform_name1': {
    #                     'custom': `{|| print 'install package_name1 on platform_name1'}`,
    #                 },
    #                 'platform_name2': {
    #                     'custom': `{|| print 'install package_name1 on platform_name2'}`,
    #                 },
    #             },
    #         },
    #     },
    # }
    # let package_data = (default {} | transpose name data
    #     | update data.install {|row|
    #         $row.data.install
    #         | transpose platform methods
    #         | update methods {|row| $row.methods | transpose package_manager_name package_id}
    #         | flatten --all
    #     }
    # )
    # $package_data
    let source = ($in)
    mut package_data = []
    mut customs = {}
    for $row in ($source | default {} | transpose name data
        | each {|row|
            $row | update data.install {|r|
                $r.data.install
                | transpose platform methods
                | update methods {|r2| $r2.methods | transpose package_manager_name package_id}
                | flatten --all
            }
            | flatten --all
            | flatten install
        } | flatten
    ) {
        # NOTE::DEBUG
        #$package_data ++= $row
        $package_data ++= (
            if (($row | get install.package_manager_name) == 'custom') {
                $customs = ($customs | insert ([$row.install.platform, $row.name] | into cell-path) {|r|$row.install.package_id})
                $row | update install.package_id {|r| [$r.install.platform, $row.name] | str join '.'}
            } else {$row}
        )
    }
    # NOTE::DEBUG
    #$package_data | skip 9 | first 5 | table -e
    {'customs': ($customs), 'data': ($package_data)}

        #mut customs = {}
        #let custom_rows = $install_data | where package_manager_name == 'custom'
        #for $row in $custom_rows {
        #    $customs = ($customs | insert ([$row.platform, $name] | into cell-path) {|r| $row.package_id})
        #}
        #($install_data
        #| where package_manager_name != 'custom'
        #| filter {|it|
        #    let cell_path_table = [['value', 'optional']; [$it.platform, false] [$it.package_manager_name, true]]
        #    $env.PACKAGE_MANAGER_DATA | get ($cell_path_table | into cell-path) | is-empty
        #}
        #| each {|it| log error $'package manager ($it.package_manager_name | to nuon) not registered for platform ($it.platform | to nuon)'}
        #| each {|it| return (error make {'msg': '1 or more package managers were not registered with the appropriate platform'})}
        #)
        #let modified = (
        #    $install_data
        #    | each {|it|
        #        if $it.package_manager_name == 'custom' {
        #            $it | update package_id {|row| view source $row.package_id}
        #        } else {
        #            $it
        #        }
        #    } | group-by --to-table platform
        #    | rename platform install
        #    | update install {|row| $row.install | reject platform | transpose --as-record --header-row}
        #    | transpose --as-record --header-row
        #)
        #let package_data = ({
        #    'install': $modified, 
        #    'search_help': ($search_help | default []),
        #    'tags': ($tags | default []),
        #    'reasons': ($reasons | default []),
        #    'links': ($links | default []),
        #})
        #{'customs': ($customs), 'data': ($packages.data | insert $name $package_data)}
}

# returns the path of the main package data file
export def "data-path" [] {
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
export def "customs-data-path" [] {
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

# saves package data, optionally to a specified path
# if no data is provided, it automatically uses `package data generate`
# output can be piped to `load-env` to update the environment
export def "save-data" [
    # optional path of where to save the package data to
    --data-path: path,
    # optional path of where to save the customs data to
    --customs-path: path,
] {
    let data = default (generate)
    $data.customs | transpose platform_name install |
    update install {|row| $row.install | transpose package_name closure | update closure {|row| view source ($row.closure)}} |
    each {|it|
        $'    ($it.platform_name | to nuon): {' | append ($it.install | each {|e|
                $'        ($e.package_name | to nuon): ($e.closure),'
        }) | append '    },'
    } | flatten | prepend [
        `# this file is auto-generated`,
        `# please edit scripts/package/data.nu instead`,
        ``,
        `# load data into environment variable`,
        `export-env { $env.PACKAGE_CUSTOMS_DATA = (main) }`,
        ``,
        `# returns the customs data`,
        `export def main [] {$env | get PACKAGE_CUSTOMS_DATA? | default {`,
    ] | append [
        `}}`,
    ] | str join "\n" | save -f ($customs_path | default (
        if ((customs-data-path) | path dirname | path exists) == true {
            (customs-data-path)
        } else {
            mkdir ((customs-data-path) | path dirname)
            (customs-data-path)
        }
    ))
    $data.data | to nuon --indent 4 | save -f ($data_path | default (
        if ((data-path) | path dirname | path exists) == true {
            (data-path)
        } else {
            mkdir ((data-path) | path dirname)
            (data-path)
        }
    ))
    if not (nu-check ($customs_path | default (customs-data-path))) {
        use std [log]
        log error $'generated customs.nu is not valid!'
        return (error make {
            'msg': $'generated .nu file is not valid -> ($customs_path | default (customs-data-path))',
        })
    }
    {'PACKAGE_DATA': ($data.data), 'PACKAGE_CUSTOMS_DATA': ($data.customs)}
}

# reads package data, optionally from specified file
export def main [
    # optional path to read package data from (defaults to `package data data-path`)
    --path: path,
] {
    open --raw ($path | default (data-path)) | from nuon
}

# function to modify to add package data
export def generate [] {
    (
    add 'winget' {'windows': {'custom': {||
        use utils.nu [powershell-safe]
        powershell-safe -c ([
            `if (-not (Get-AppxPackage Microsoft.DesktopAppInstaller)) {`,
            `    Add-AppxPackage "https://aka.ms/getwinget"`,
        # https://learn.microsoft.com/en-us/windows/package-manager/winget/
            `    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe`,
            `}`,
        ] | str join '')
    }}} --tags ['essential', 'package manager'] |
    add 'scoop' {'windows': {'custom': {||
        use utils.nu [powershell-safe]
        powershell-safe --less-safe -c ([
            `if (-not (gcm scoop -ErrorAction SilentlyContinue)) {`,
            `    irm -useb "https://get.scoop.sh" | iex`,
            `    scoop install aria2 git`,
            `    scoop bucket add extras`,
            `}`,
        ] | str join '')
    }}} --tags ['essential', 'package manager'] |
    add 'pipx' {'windows': {'custom': {||
                # use package/install.nu [main]
                # main 'scoop'
                # main 'python'
        ^python -m pip install --user --upgrade pip setuptools wheel pipx
    }}} --tags ['essential', 'package manager'] |
    add 'python' {'windows': {'scoop': 'python'}} --tags ['essential', 'language'] |
    add 'aria2' {'windows': {'scoop': 'aria2'}} --tags ['scoop'] --reasons ['helps scoop download stuff better'] |
    add 'clink' {'windows': {'scoop': 'clink'}} --tags ['essential'] --reasons ["makes Windows' CMD easier to use", "enables starship in CMD"] |
    add 'git' {'windows': {'scoop': 'git'}} --tags ['essential'] --reasons ['revision control and source management', 'downloading programs'] --links ['https://git-scm.com/docs'] |
    # add 'example1' {'platform1': {'custom': {|| print 'installing example1 to platform1'}}, 'platform2': {'custom': {|| print 'installing example1 to platform2'}}} |
    # add 'example2' {'platform1': {'custom': {|| print 'installing example2 to platform1'}}, 'platform3': {'custom': {|| print 'installing example2 to platform3'}}}

    add "7zip" {"windows": {"scoop": "7zip"}} --tags ['scoop', 'exclude', 'auto'] |
    add "7zip19.00-helper" {"windows": {"scoop": "7zip19.00-helper"}} --tags ['scoop', 'exclude', 'auto'] |
    add "audacity" {"windows": {"scoop": "audacity"}} --tags ['rarely', 'large'] |
    add "caddy" {"windows": {"scoop": "caddy", "winget": "CaddyServer.Caddy"}, "linux": {"apt-get": "caddy"}} --tags ['small', 'rarely'] |
    add "dark" {"windows": {"scoop": "dark"}} --tags ['scoop', 'exclude', 'auto'] |
    add "dejavusansmono-nf" {"windows": {"scoop": "dejavusansmono-nf"}} --tags ['essential'] |
    add "duckdb" {"windows": {"scoop": "duckdb"}} --tags ['small', 'undecided'] --reasons ['cool database engine in same space as SQLite, but under really cool, active development by academics, with really cool features'] |
    add "eget" {"windows": {"scoop": "eget"}} --tags ['essential'] --reasons ['makes installing stuff from GitHub releases much easier'] --links ['https://github.com/zyedidia/eget?tab=readme-ov-file#eget-easy-pre-built-binary-installation'] |
    add "fd" {"windows": {"scoop": "fd"}} --tags ['essential'] --search-help ['find', 'rust'] |
    add "ffmpeg" {"windows": {"scoop": "ffmpeg"}} --tags ['large', 'essential', 'yt-dlp'] |
    add "filezilla" {"windows": {"scoop": "filezilla"}} --tags ['filezilla'] |
    add "fontforge" {"windows": {"scoop": "fontforge"}} --tags ['rarely'] |
    add "foobar2000" {"windows": {"scoop": "foobar2000"}} --tags ['why_even'] --reasons ['has an ABX plugin that makes comparing two songs to see which one is encoded in a better qualitymuch easier'] |
    add "freac" {"windows": {"scoop": "freac"}} --tags ['why_even'] |
    add "fvim" {"windows": {"scoop": "fvim"}} --tags ['why_even'] --reasons ['at one point, before neovide, was really good with the Comic Code font'] |
    add "gifsicle" {"windows": {"scoop": "gifsicle"}} --tags ['small', 'rarely'] --reasons ['used by other programs like Screen2Gif to minify gifs'] |
    add "gifski" {"windows": {"scoop": "gifski"}} --tags ['small', 'rarely'] --reasons ['used by other programs like Screen2Gif to minify gifs'] |
    add "gnupg" {"windows": {"scoop": "gnupg"}} --tags ['essential', 'small'] |
    add "handbrake" {"windows": {"scoop": "handbrake"}} --tags ['rarely', 'large'] |
    add "hashcat" {"windows": {"scoop": "hashcat"}} --tags ['why_even'] --reasons ['tries to make cracking hashes and guessing passwords easier'] |
    add "imageglass" {"windows": {"scoop": "imageglass"}} --tags ['rarely'] --reasons ['nicer image viewer', 'can display and convert iPhone .avif images for free'] --search-help ['avif', 'av1', 'iPhone', 'picture'] |
    add "inkscape" {"windows": {"scoop": "inkscape"}} --tags ['large'] |
    add "innounp" {"windows": {"scoop": "innounp"}} --tags ['scoop', 'exclude', 'auto'] |
    add "jq" {"windows": {"scoop": "jq"}} --tags ['small', 'essential'] |
    add "keepass" {"windows": {"scoop": "keepass"}} --tags ['essential', 'keepass'] |
    add "keepass-plugin-keetraytotp" {"windows": {"scoop": "keepass-plugin-keetraytotp"}} --tags ['essential', 'keepass'] |
    add "keepass-plugin-readable-passphrase" {"windows": {"scoop": "keepass-plugin-readable-passphrase"}} --tags ['essential', 'keepass'] |
    add "libreoffice" {"windows": {"scoop": "libreoffice"}} --tags ['large'] --reasons ['libreoffice draw is good at editing PDFs in complex ways'] |
    add "libxml2" {"windows": {"scoop": "libxml2"}} --tags ['why_even'] --reasons ['was used for rendering DocBook documents, like rendering the .epub of PostgreSQL documentation'] |
    add "love" {"windows": {"scoop": "love"}} --tags ['small', 'rarely', 'game', 'fun', 'lua'] --reasons ["small game framework for lua that I've never really gotten to use"] |
    add "luajit" {"windows": {"scoop": "luajit"}} --tags ['small', 'essential', 'language', 'lua'] --reasons ['fast lua runtime'] |
    add "mariadb" {"windows": {"scoop": "mariadb"}} --tags ['large', 'rarely'] |
    add "mpv" {"windows": {"scoop": "mpv"}} --tags ['essential'] --reasons ['has fewer visual "glitches" than vlc, and plays as wide a variety of media, including HEVC/h.265 for free'] |
    add "neovide" {"windows": {"scoop": "neovide"}} --tags ['essential'] |
    add "neovim" {"windows": {"scoop": "neovim"}} --tags ['essential'] |
    add "notepadplusplus" {"windows": {"scoop": "notepadplusplus"}} --tags ['small', 'rarely', 'essential'] |
    add "nu" {"windows": {"scoop": "nu"}} --tags ['essential', 'small'] |
    add "obs-studio" {"windows": {"scoop": "obs-studio"}} --tags ['large'] |
    add "pandoc" {"windows": {"scoop": "pandoc"}} --tags ['small', 'rarely'] --reasons ['really good at converting one document format to another'] |
    add "peazip" {"windows": {"scoop": "peazip"}} --tags ['essential'] --reasons ['much nicer interface than 7zip, can do all the same stuff'] |
    add "picard" {"windows": {"scoop": "picard"}} --tags ['large', 'rarely', 'music'] --reasons ['makes organizing and tagging songs, and wrangling metadata, much easier'] --search-help ['musicbrainz'] |
    add "postgresql" {"windows": {"scoop": "postgresql"}} --tags ['large', 'rarely'] |
    add "pwsh" {"windows": {"scoop": "pwsh"}} --tags ['essential', 'rarely'] --reasons ['better powershell'] |
    add "rclone" {"windows": {"scoop": "rclone"}} --tags ['small', 'rarely', 'essential'] --reasons ['makes copying files between the cloud and locally much, much easier'] |
    add "ripgrep" {"windows": {"scoop": "ripgrep"}} --tags ['small', 'essential'] --reasons ['cross-platform, faster grep'] --search-help ['rg'] |
    add "rufus" {"windows": {"scoop": "rufus"}} --tags ['small', 'essential', 'gui'] --reasons ['makes creating bootable flashdrives much, much easier'] |
    add "screentogif" {"windows": {"scoop": "screentogif"}} --tags ['gui', 'rarely'] --reasons ['makes screen recording quite quick and simple'] |
    add "shellcheck" {"windows": {"scoop": "shellcheck"}} --tags ['language', 'small', 'rarely', 'tooling', 'shell', 'sh'] --reasons ['lints POSIX shell scripts'] |
    add "sqlite" {"windows": {"scoop": "sqlite"}} --tags ['small', 'essential', 'language'] --reasons ['beloved database engine that makes using SQL a breeze', 'sqlean is better if I can get it'] |
    add "sqlitebrowser" {"windows": {"scoop": "sqlitebrowser"}} --tags ['why_even', 'exclude'] --reasons ['visualizes a sqlite database, but I can do that with the sqlite cli'] |
    add "starship" {"windows": {"scoop": "starship"}} --tags ['essential', 'style'] --reasons ['makes my shell prompt cross-platform, cross-shell, and nice'] |
    add "stylua" {"windows": {"scoop": "stylua"}} --tags ['small', 'tooling', 'lua'] --reasons ['auto-formatting lua'] |
    add "taplo" {"windows": {"scoop": "taplo"}} --tags ['small', 'tooling', 'toml'] --reasons ['I think it can lint TOML files? I think I installed it for conform.nvim'] |
    add "transmission" {"windows": {"scoop": "transmission"}} --tags ['small', 'rarely'] --reasons ['my preferred (bit)torrent client'] |
    add "tree-sitter" {"windows": {"scoop": "tree-sitter"}} --tags ['essential'] --reasons ['works with neovim to make highlighting and editing much nicer'] |
    add "upx" {"windows": {"scoop": "upx"}} --tags ['small', 'rarely', 'tooling'] --reasons ['free, open source executable packer, to make executables as small as possible'] |
    add "vlc" {"windows": {"scoop": "vlc"}} --tags ['essential', 'small'] --reasons ['beloved media player', 'can do lots of cool tricks'] |
    add "windirstat" {"windows": {"scoop": "windirstat"}} --tags ['essential', 'small'] --reasons ['visualizes hard drive allocation by file size', 'makes it much, much easier to find large files taking up hard drive space and delete them'] |
    add "wsl-ssh-pageant" {"windows": {"scoop": "wsl-ssh-pageant"}} --tags ['essential', 'gnupg', 'windows'] --reasons ['makes it possible to use gnupg as an ssh agent on Windows'] |
    add "xmplay" {"windows": {"scoop": "xmplay"}} --tags ['small', 'gui', 'music', 'rarely'] --reasons ['has a cool rabbit hole visualizer plugin, and can play MOD files'] |
    add "zig" {"windows": {"scoop": "zig"}} --tags ['language', 'essential', 'compiler'] --reasons ['cool language', 'acts as my cross-platform C compiler'] |
    add "zstd" {"windows": {"scoop": "zstd"}} --tags ['small', 'why_even'] --reasons ['allows me to get more compression out of zstd than PeaZip'] |
    add "mullvadvpn" {"windows": {"winget": "MullvadVPN.MullvadVPN"}} --tags ['small', 'vpn'] --reasons ['beloved, occasionally used vpn client'] |
    add "Microsoft.VisualStudio.2022.BuildTools" {"windows": {"winget": "Microsoft.VisualStudio.2022.BuildTools"}} --tags ['large', 'compiler', 'rust', 'tooling', 'C', 'C++'] --reasons ['used by rust to compile/link stuff on Windows'] |
    add "discord" {"windows": {"winget": "Discord.Discord"}} --tags ['large', 'gui', 'essential', 'chat'] |
    add "Google.Chrome.EXE" {"windows": {"winget": "Google.Chrome.EXE"}} --tags ['large', 'browser'] |
    add "imagemagick" {"windows": {"winget": "ImageMagick.ImageMagick"}} --tags ['large'] --reasons ['can convert any image format into any image format', 'cli program for manipulating images', 'use to use it for generating art, like my desktop background and phone lockscreen'] |
    add "Microsoft.Edge" {"windows": {"winget": "Microsoft.Edge"}} --tags ['exclude', 'large', 'system'] |
    add "Microsoft.EdgeWebView2Runtime" {"windows": {"winget": "Microsoft.EdgeWebView2Runtime"}} --tags ['system', 'exclude'] |
    add "Microsoft.AppInstaller" {"windows": {"winget": "Microsoft.AppInstaller"}} --tags ['essential', 'winget'] --reasons ['provides winget'] |
    add "Microsoft.UI.Xaml.2.7" {"windows": {"winget": "Microsoft.UI.Xaml.2.7"}} --tags ['exclude'] |
    add "Microsoft.UI.Xaml.2.8" {"windows": {"winget": "Microsoft.UI.Xaml.2.8"}} --tags ['exclude'] |
    add "Microsoft.VCLibs.Desktop.14" {"windows": {"winget": "Microsoft.VCLibs.Desktop.14"}} --tags ['exclude'] |
    add "Microsoft.WindowsTerminal" {"windows": {"winget": "Microsoft.WindowsTerminal"}} --tags ['essential', 'gui', 'windows'] --reasons ['use to be my favorite terminal emulator before neovide+neovim'] |
    add "Microsoft.Teams.Free" {"windows": {"winget": "Microsoft.Teams.Free"}} --tags ['exclude', 'remove'] |
    add "Mozilla.Firefox" {"windows": {"winget": "Mozilla.Firefox"}} --tags ['essential', 'large'] --reasons ['beloved browser'] |
    add "Microsoft.OneDrive" {"windows": {"winget": "Microsoft.OneDrive"}} --tags ['essential', 'system'] --reasons ['what I use to sync all my files cross-platform'] |
    add "Rustlang.Rustup" {"windows": {"winget": "Rustlang.Rustup"}} --tags ['tooling', 'language', 'rust'] --reasons ["rust's main way of managing compiler versions"] |
    add "Valve.Steam" {"windows": {"winget": "Valve.Steam"}} --tags ['gui', 'games', 'large'] |
    add "DigitalExtremes.Warframe" {"windows": {"winget": "DigitalExtremes.Warframe"}} --tags ['exclude'] |
    add "universalmediaserver" {"windows": {"winget": "UniversalMediaServer.UniversalMediaServer"}} --tags ['large'] --reasons ['does all the local network hosting and live, on-the-fly transcoding of videos really easy', "upnp media server compatible with my Roku TV's Roku Media Player"] |
    add "zint" {"windows": {"winget": "Zint.Zint"}} --tags ['small', 'gui', 'windows', 'barcodes'] --reasons ['beloved barcode creation studio'] |
    add "zoom" {"windows": {"winget": "Zoom.Zoom"}} --tags ['office'] |
    add "libjpeg-turbo.libjpeg-turbo.VC" {"windows": {"winget": "libjpeg-turbo.libjpeg-turbo.VC"}} --tags ['exclude', 'auto'] |
    add "Microsoft.VCRedist.2013.x64" {"windows": {"winget": "Microsoft.VCRedist.2013.x64"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2010.x64" {"windows": {"winget": "Microsoft.VCRedist.2010.x64"}} --tags ['exclude'] |
    add "GlavSoft.TightVNC" {"windows": {"winget": "GlavSoft.TightVNC"}} --tags ['essential'] --reasons ['my preferred VNC remote desktop solution', 'I use the RealVNC app on Android an iOS']|
    add "Microsoft.VCRedist.2012.x86" {"windows": {"winget": "Microsoft.VCRedist.2012.x86"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2015+.x86" {"windows": {"winget": "Microsoft.VCRedist.2015+.x86"}} --tags ['exclude'] |
    add "Telegram.TelegramDesktop" {"windows": {"winget": "Telegram.TelegramDesktop"}} --tags ['chat', 'gui', 'rarely'] --reasons ['desktop chat client, but I can also use the web app'] |
    add "Microsoft.DotNet.DesktopRuntime.6" {"windows": {"winget": "Microsoft.DotNet.DesktopRuntime.6"}} --tags ['exclude'] |
    add "Microsoft.CLRTypesSQLServer.2019" {"windows": {"winget": "Microsoft.CLRTypesSQLServer.2019"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2008.x64" {"windows": {"winget": "Microsoft.VCRedist.2008.x64"}} --tags ['exclude'] |
    add "PlayStation.DualSenseFWUpdater" {"windows": {"winget": "PlayStation.DualSenseFWUpdater"}} --tags ['windows', 'rarely'] --reasons ['DualSense / DualShock5 / DS5 firmware updating tool'] |
    add "ViGEm.ViGEmBus" {"windows": {"winget": "ViGEm.ViGEmBus"}} --tags ['games', 'windows', 'ds4windows'] --reasons ['used by ds4windows'] |
    add "ElectronicArts.EADesktop" {"windows": {"winget": "ElectronicArts.EADesktop"}} --tags ['exclude', 'auto'] |
    add "Microsoft.VCRedist.2008.x86" {"windows": {"winget": "Microsoft.VCRedist.2008.x86"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2013.x86" {"windows": {"winget": "Microsoft.VCRedist.2013.x86"}} --tags ['exclude'] |
    add "Nvidia.PhysXLegacy" {"windows": {"winget": "Nvidia.PhysXLegacy"}} --tags ['exclude'] |
    add "EpicGames.EpicGamesLauncher" {"windows": {"winget": "EpicGames.EpicGamesLauncher"}} --tags ['games', 'large'] |
    add "Mozilla.VPN" {"windows": {"winget": "Mozilla.VPN"}} --tags ['rarely', 'vpn'] --reasons ['used to use this VPN for a bit; when I used it, they were using Mullvad as the provider'] |
    add "winfsp" {"windows": {"winget": "WinFsp.WinFsp"}} --tags ['not sure', 'windows'] --reasons ['I think another program required it'] --links ['https://github.com/winfsp/winfsp'] |
    add "Microsoft.VCRedist.2010.x86" {"windows": {"winget": "Microsoft.VCRedist.2010.x86"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2015+.x64" {"windows": {"winget": "Microsoft.VCRedist.2015+.x64"}} --tags ['exclude'] |
    add "Microsoft.VCRedist.2012.x64" {"windows": {"winget": "Microsoft.VCRedist.2012.x64"}} --tags ['exclude'] |
    add "black" {"windows": {"pipx": "black"}} --tags ['essential', 'tooling', 'python'] --reasons ['python auto formatter']|
    add "build" {"windows": {"pipx": "build"}} --tags ['rarely', 'tooling', 'python'] --reasons ['used for building some distributions'] |
    add "certbot" {"windows": {"pipx": "certbot"}} --tags ['webserver', 'ssl', 'rarely'] --reasons ['makes getting a letsencrypt certificate much, much easier', 'caddy is better, as it handles that acme protocol itself, and is a very flexible webserver'] |
    add "commitizen" {"windows": {"pipx": "commitizen"}} --tags ['essential', 'tooling'] --reasons ['helps me remember how to format git commit messages'] |
    add "httpie" {"windows": {"pipx": "httpie"}} --tags ['curl'] --reasons ["much nicer to use, but slightly less full-featured than curl (I've never hit those limits, thought)"] |
    add "isort" {"windows": {"pipx": "isort"}} --tags ['old', 'python', 'tooling'] --reasons ['auto code formatter specifically for imports', 'now I use ruff or usort', "last time I checked, this didn't use a parser, just regex, and that scared me"] |
    add "mypy" {"windows": {"pipx": "mypy"}} --tags ['essential', 'python', 'tooling', 'language'] --reasons ['python type checker', "I basically don't write Python without it"] |
    add "poetry" {"windows": {"pipx": "poetry"}} --tags ['old', 'python', 'tooling'] --reasons ['dependency and package/project manager for Python'] --links ['https://github.com/python-poetry/poetry/', 'https://python-poetry.org/'] |
    add "py-spy" {"windows": {"pipx": "py-spy"}} --tags ['python', 'tooling'] --reasons ['python performance monitoring tool that can hook into a running Python process to produce a flamegraph, or provide a top-like interface to watch which codepaths are being run the most frequently, and/or spending the most time being run', 'can help uncover deadlocks without having to use gdb'] |
    add "pyclip" {"windows": {"pipx": "pyclip"}} --tags ['essential', 'clipboard'] --reasons ['makes working with the clipboard consistent across platforms; even Windows'] |
    add "pygount" {"windows": {"pipx": "pygount"}} --tags ['small', 'rarely', 'python', 'tooling'] --reasons ['python LOCs (lines of code) reporting tool (recognizes languages other than Python'] |
    add "pylint" {"windows": {"pipx": "pylint"}} --tags ['python', 'tooling'] --reasons ['linting for Python', 'ruff is cirrently doing a great job', 'detects the most things'] |
    add "pytest" {"windows": {"pipx": "pytest"}} --tags ['python', 'tooling', 'essential'] --reasons ['incredible python testing framework', 'indispensible'] |
    add "ruff" {"windows": {"pipx": "ruff"}} --tags ['python', 'tooling', 'essential'] --reasons ['auto formats and lints python code incredibly quickly'] |
    add "ruff-lsp" {"windows": {"pipx": "ruff-lsp"}} --tags ['python', 'tooling', 'neovim'] --reasons ['makes ruff easy to use with neovim; used by conform.nvim'] |
    add "sqlfluff" {"windows": {"pipx": "sqlfluff"}} --tags ['sql', 'tooling'] --reasons ['linting for sql', "don't know how to use/configure it"] |
    add "tox" {"windows": {"pipx": "tox"}} --tags ['python', 'tooling'] --reasons ['beloved test runner', 'makes it super nice to have very isolated test environments, and can run the tests across multiple versions of Python'] |
    add "twine" {"windows": {"pipx": "twine"}} --tags ['small', 'python', 'tooling'] --reasons ['was the blessed tool to upload packages to PyPI'] |
    add "usort" {"windows": {"pipx": "usort"}} --tags ['python', 'tooling'] --reasons ['large-coproration-made replacement for isort'] |
    add "xonsh" {"windows": {"pipx": "xonsh"}} --tags ['python', 'shell', 'environment', 'rarely'] --reasons ['beloved cross-platform shell; extremely friendly to python'] |
    add "youtube-dl" {"windows": {"pipx": "youtube-dl"}} --tags ['old', 'small'] --reasons ['used to be my favorite (youtube) video downloader before yt-dlp'] |
    add "yt-dlp" {"windows": {"pipx": "yt-dlp"}} --tags ['small', 'essential', 'yt-dlp'] --reasons ['really, really good (youtube) video downloader based on youtube-dl'] |
    add "exiv2" {"linux": {"apt-get": "exiv2"}} --tags ['small'] --reasons ['my favorite tool for reading and manipulating EXIF data in images'] --search-help ['picture'] |
    add "exiftool" {"windows": {"scoop": "exiftool", "winget": "exiftool"}, "linux": {"apt-get": "exiftool"}} --tags ['small'] --reasons ['popular EXIF image metadata manipulation program'] --search-help ['picture'] |
    add "sqlean" {"windows": {"custom": {|| ^eget 'nalgeon/sqlite' '/a' 'sqlean.exe'}}} --tags ['small', 'essential'] --reasons ['fantastic recompile of SQLite to include really useful extensions'] --links ['https://github.com/nalgeon/sqlite']
    ) |
    separate-customs
}
