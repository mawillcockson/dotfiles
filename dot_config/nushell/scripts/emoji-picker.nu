use consts.nu [platform]

export const suggested_default_query = [
    '-or',
    'g:smileys',
    'g:hand-fingers-open',
    'g:hand-fingers-partial',
    'g:hand-single-finger',
    'g:hand-fingers-closed',
    'g:hands',
    'g:body-parts',
    'g:person-gesture',
]
export const default_query = []
export const uni_cmd = [
    'uni',
    '--compact',
    'emoji',
    '-gender', 'person',
    '-tone', 'light',
]

export def main [
    --start-terminal,
    ...query: string,
] {
    let query = (
        if ($query | is-empty) {
            $default_query | str join ' '
        } else if ($query | describe) == 'list<string>' {
            $query | str join ' '
        } else {
            $query
        }
    )
    let fzf_command = [
            fzf
                --disabled
                --ignore-case
                --no-sort
                --cycle
                $'--history=($nu.temp-path | path join "emoji-picker-history.txt")'
                --history-size=1000
                $'--query=($query)'
                --select-1
                '--with-shell=nu -c'
                $"--bind=change:reload:$env.FZF_QUERY | split row \(char space\) | prepend ($uni_cmd | to nuon) | run-external \($in | first\) ...\($in | skip 1\)"
                $"--bind=enter:execute#overlay use --prefix clipboard.nu; ($uni_cmd | to nuon) | append ['-as', 'json'] | append \($env.FZF_QUERY | split row ' '\) | run-external \($in | first\) ...\($in | skip 1\) | from json | get emoji | get \($env.FZF_POS | into int | \($in - 1\) | into cell-path\) | clipboard clip --silent --no-notify --no-strip --codepage 65001#+accept"
    ]

    mut cmd = []
    if $start_terminal {
        $cmd ++= match ($platform) {
            'windows' if (which wt | is-not-empty) => {
                [
                    wt,
                        --focus
                        --window, new,
                        new-tab,
                        -p, Neovim,
                        --suppressApplicationTitle,
                        --title, emoji-picker,
                ]
            },
            'linux' if (which alacritty | is-not-empty) => {
                [
                    alacritty,
                    --title, emoji-picker,
                    --command,
                ]
            }
            _ => {
                log warning $"don't know how to start a terminal for platform ($platform | to nuon)"
                []
            },
        }
    }
    $cmd ++= $fzf_command
    let cmd = $cmd

    with-env {
        'FZF_DEFAULT_COMMAND': ($uni_cmd | append $query | str join ' '),
    } {
        run-external ($cmd | first) ...($cmd | skip 1)
    }
}
