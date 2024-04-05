# Instead of including dependency information, each package is assumed to have
# dependency resolution handled by the package manager.
#
# If the package manager is 'custom', then the provided closure will be run,
# and will be expected to handle all the installation with only the minimal
# tools provided by the platform.
# To reduce duplication, custom commands should be implemented in the `ensure`
# namespace for each additional tool that the closure needs in order to run.

export def "ensure rust windows" [] {
    let rustup = if (which 'rustup' | length) == 0 {
        let tmpdir = (mktemp -d)
        let rustup = ($tmpdir | path join 'rustup.exe')
        ^curl '--tlsv1.2' --proto '=https' 'https://win.rustup.rs/x86_64' --output $rustup
        $rustup
    } else { which 'rustup' | get 0.path }
    run-external $rustup '+stable' 'update'
}

export def tags [] {
    main | select tags | flatten | uniq
}

export def select-by-tags [...rest] {
    main | filter {|it|
        $it | get tags | any {|e| $e in $rest}
    }
}

export def main [] {
[
    [
        name,
        install,
        tags,
        reasons,
        links
    ];
    [
        "aria2",
        {
            windows: {
                scoop: "aria2"
            }
        },
        [
            scoop
        ],
        [
            "helps scoop download stuff better"
        ],
        [

        ]
    ],
    [
        clink,
        {
            windows: {
                scoop: clink
            }
        },
        [
            essential
        ],
        [
            "makes Windows' CMD easier to use",
            "enables starship in CMD",
        ],
        [

        ]
    ],
    [
        git,
        {
            windows: {
                scoop: git
            }
        },
        [
            essential
        ],
        [
            "revision control and source management",
            "downloading programs",
        ],
        [
            "https://git-scm.com/docs",
        ]
    ],
    [
        gnupg,
        {
            windows: {
                scoop: gnupg
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        "7zip",
        {
            windows: {
                scoop: "7zip"
            }
        },
        [
            scoop_auto_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        dark,
        {
            windows: {
                scoop: dark
            }
        },
        [
            scoop_auto_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        innounp,
        {
            windows: {
                scoop: innounp
            }
        },
        [
            scoop_auto_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        'dejavusansmono-nf',
        {
            windows: {
                scoop: 'dejavusansmono-nf'
            }
        },
        [
            essential
            fonts
        ],
        [

        ],
        [

        ]
    ],
    [
        eget,
        {
            windows: {
                scoop: eget
            }
        },
        [
            essential
        ],
        [
            'makes installing stuff from GitHub releases much easier',
        ],
        [
            'https://github.com/zyedidia/eget?tab=readme-ov-file#eget-easy-pre-built-binary-installation',
        ]
    ],
    [
        fd,
        {
            windows: {
                scoop: fd
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        jq,
        {
            windows: {
                scoop: jq
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        mpv,
        {
            windows: {
                scoop: mpv
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        neovide,
        {
            windows: {
                scoop: neovide
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        neovim,
        {
            windows: {
                scoop: neovim
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        notepadplusplus,
        {
            windows: {
                scoop: notepadplusplus
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        nu,
        {
            windows: {
                scoop: nu
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        peazip,
        {
            windows: {
                scoop: peazip
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        python,
        {
            windows: {
                scoop: python
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        rclone,
        {
            windows: {
                scoop: rclone
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        ripgrep,
        {
            windows: {
                scoop: ripgrep
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        sqlite,
        {
            windows: {
                scoop: sqlite
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        starship,
        {
            windows: {
                scoop: starship
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        vlc,
        {
            windows: {
                scoop: vlc
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        windirstat,
        {
            windows: {
                scoop: windirstat
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        "wsl-ssh-pageant",
        {
            windows: {
                scoop: "wsl-ssh-pageant"
            }
        },
        [
            essential
        ],
        [

        ],
        [

        ]
    ],
    [
        ffmpeg,
        {
            windows: {
                scoop: ffmpeg
            }
        },
        [
            "yt-dlp"
        ],
        [

        ],
        [

        ]
    ],
    [
        keepass,
        {
            windows: {
                scoop: keepass
            }
        },
        [
            keepass
        ],
        [

        ],
        [

        ]
    ],
    [
        "keepass-plugin-keetraytotp",
        {
            windows: {
                scoop: "keepass-plugin-keetraytotp"
            }
        },
        [
            keepass
        ],
        [

        ],
        [

        ]
    ],
    [
        "keepass-plugin-readable-passphrase",
        {
            windows: {
                scoop: "keepass-plugin-readable-passphrase"
            }
        },
        [
            keepass
        ],
        [

        ],
        [

        ]
    ],
    [
        stylua,
        {
            windows: {
                scoop: stylua
            }
        },
        [
            neovim_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        taplo,
        {
            windows: {
                scoop: taplo
            }
        },
        [
            neovim_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        "tree-sitter",
        {
            windows: {
                scoop: "tree-sitter"
            }
        },
        [
            neovim_dependencies
        ],
        [

        ],
        [

        ]
    ],
    [
        inkscape,
        {
            windows: {
                scoop: inkscape
            }
        },
        [
            large
        ],
        [

        ],
        [

        ]
    ],
    [
        "obs-studio",
        {
            windows: {
                scoop: "obs-studio"
            }
        },
        [
            large
        ],
        [

        ],
        [

        ]
    ],
    [
        caddy,
        {
            windows: {
                scoop: caddy
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        duckdb,
        {
            windows: {
                scoop: duckdb
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        gifsicle,
        {
            windows: {
                scoop: gifsicle
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        gifski,
        {
            windows: {
                scoop: gifski
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        love,
        {
            windows: {
                scoop: love
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        luajit,
        {
            windows: {
                scoop: luajit
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        pandoc,
        {
            windows: {
                scoop: pandoc
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        rufus,
        {
            windows: {
                scoop: rufus
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        shellcheck,
        {
            windows: {
                scoop: shellcheck
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        transmission,
        {
            windows: {
                scoop: transmission
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        upx,
        {
            windows: {
                scoop: upx
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        xmplay,
        {
            windows: {
                scoop: xmplay
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        zig,
        {
            windows: {
                scoop: zig
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        zstd,
        {
            windows: {
                scoop: zstd
            }
        },
        [
            small_rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        audacity,
        {
            windows: {
                scoop: audacity
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        filezilla,
        {
            windows: {
                scoop: filezilla
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        fontforge,
        {
            windows: {
                scoop: fontforge
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        handbrake,
        {
            windows: {
                scoop: handbrake
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        hashcat,
        {
            windows: {
                scoop: hashcat
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        imageglass,
        {
            windows: {
                scoop: imageglass
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        libreoffice,
        {
            windows: {
                scoop: libreoffice
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        picard,
        {
            windows: {
                scoop: picard
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        screentogif,
        {
            windows: {
                scoop: screentogif
            }
        },
        [
            rarely
        ],
        [

        ],
        [

        ]
    ],
    [
        "foobar2000",
        {
            windows: {
                scoop: "foobar2000"
            }
        },
        [
            why_even
        ],
        [

        ],
        [

        ]
    ],
    [
        freac,
        {
            windows: {
                scoop: freac
            }
        },
        [
            why_even
        ],
        [

        ],
        [

        ]
    ],
    [
        fvim,
        {
            windows: {
                scoop: fvim
            }
        },
        [
            why_even
        ],
        [

        ],
        [

        ]
    ],
    [
        "libxml2",
        {
            windows: {
                scoop: "libxml2"
            }
        },
        [
            why_even
        ],
        [

        ],
        [

        ]
    ],
    [
        'atuin',
        {
            'windows': {
                'custom': {||
                    ensure rust windows
                    ^cargo install atuin
                },
            },
        },
        [
            'essential',
        ],
        [

        ],
        [

        ],
    ],
    [
        'rust',
        {
            'windows': {
                'custom': {|| ensure rust windows },
            },
        },
        [
            'large'
        ],
        [

        ],
        [

        ],
    ],
    [
        'fake1',
        {
            'windows': {
                'custom': {||},
            },
        },
        [ 'test' ],
        [],
        [],
    ],
    [ 'fake2', {'windows':{'winget': 'fake'}},['test'],[],[]],
]
}
