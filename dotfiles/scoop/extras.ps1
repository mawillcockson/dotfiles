foreach ($i in @(
    'black',
    'build',
    'commitizen',
    'httpie',
    'isort',
    'mypy',
    'poetry',
    'py-spy',
    'pyclip',
    'pygount',
    'pylint',
    'pytest',
    'ruff',
    'ruff-lsp',
    'sqlfluff',
    'tox',
    'twine',
    'usort',
    'xonsh[full]'
    'yt-dlp',
)) {
    python -m pipx install "$i"
}
python -m pipx inject pytest 'pytest-cov'

scoop install

clink                              1.6.9                     main       2024-03-18 21:40:34
starship                           1.17.1                    main       2024-01-24 14:53:23

jq                                 1.7.1                     main       2023-12-23 13:14:38
fd                                 9.0.0                     main       2023-12-23 13:14:10
ripgrep                            14.1.0                    main       2024-01-24 14:53:20
shellcheck                         0.10.0                    main       2024-03-18 23:05:16
upx                                4.2.2                     main       2024-01-24 14:53:25

caddy                              2.7.6                     main       2024-02-11 22:11:19
ffmpeg                             6.1.1                     main       2023-12-31 09:15:20
pandoc                             3.1.12.3                  main       2024-03-18 21:40:41
rclone                             1.66.0                    main       2024-03-13 01:36:45
rufus                              4.4                       extras     2024-01-24 14:52:04
sqlite                             3.45.2                    main       2024-03-13 01:36:47

mpv                                0.37.0                    extras     2023-12-23 13:14:57
windirstat                         1.1.2                     extras     2022-06-05 00:46:12
