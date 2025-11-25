# $env.NU_LOG_LEVEL = 'debug'

let tmux_command = if (which 'tmux' | is-not-empty) and ('TMUX' not-in $env) {
    let has_session = ((^tmux has-session | complete | get exit_code) == 0)

    if ($has_session) == true {
        let has_ssh = ((^tmux has-session -t ssh | complete | get exit_code) == 0)
        if ($has_ssh) == true {
            'tmux attach -t ssh'
        } else {
            'tmux attach -d'
        }
    } else {
        match ($nu.os-info.name) {
            'android' => { 'tmux -f ~/.tmux.conf' },
            _ => { 'tmux' },
        }
    }
} else if (which 'tmux' | is-not-empty) {
    ' # tmux already running'
} else {
    'nu -c "use package; package install tmux"'
}

let remove_tmux_helpers = r##'
    $env.config.keybindings = (
        $env.config.keybindings |
        each {|it|
            if ($it | get name?) == 'tmux_helper' {
                $it | update event null
            } else { $it }
        }
    )

    $env.config.hooks.pre_execution = (
        $env.config.hooks.pre_execution |
        where {|it| ($it != {code: ($remove_tmux_helpers)}) }
    )
'## ##'

# Atuin should be able to handle a lot of history, so don't cull based on
# number of entries
$env.config.history.max_size = 10_000_000
$env.config.history.file_format = 'sqlite'

$env.config.filesize = {unit: binary, precision: 2}

$env.config.buffer_editor = (
    if ('NVIM' in $env) and (which nvr | is-not-empty) {
# if running in Neovim, use that as our editor
        [nvr -cc split --remote-wait]
    } else if (which nvim | is-not-empty) {
# otherwise use Neovim itself
        [nvim]
    } else if ('EDITOR' in $env) and ($env.EDITOR | is-not-empty) {
        [$env.EDITOR]
    } else {null}
)

# I like vi keybindings
$env.config.edit_mode = 'vi'

# I have my own banner in an autoload :)
$env.config.show_banner = false

# Use a non-emoji absent value indicator
$env.config.table.missing_value_symbol = "∅"

$env.config.hooks.pre_execution ++= [
    {code: ($remove_tmux_helpers)},
]
$env.config.hooks.env_change = $env.config.hooks.env_change | merge deep --strategy append {
    PWD: [
        #{code: {|before,after| use std/log; log debug $'cd-ing ($before) -> ($after)' }},
        {
            # if I cd into a directory named 'ziglings.org', prepend
            # '~/apps/zigmaster' to $PATH
            'condition': {|_, after|
                (
                    (($after | path basename) == 'ziglings.org')
                    and
                    ('~/apps/zigmaster/' | path expand | path exists)
                )
            },
            'code': {|_, _| load-env {'PATH': ($env.PATH | prepend ('~/apps/zigmaster' | path expand --strict))}},
        },
        {
            # if I leave a directory that has 'ziglings.org' as it or a
            # parent's name, remove '~/apps/zigmaster' from $PATH
            'condition': {|before, after|
                (
                    ($before | is-not-empty) # happens on startup
                    and
                    ('ziglings.org' in ($before | path split))
                    and
                    ('ziglings.org' not-in ($after | path split))
                )
            },
            'code': {|_, _|
                load-env {
                    'PATH': (
                        $env.PATH |
                        where {|it| $it != ('~/apps/zigmaster' | path expand) }
                    ),
                }
            },
        },
    ],
}

$env.config.keybindings ++= [
    {
        name: 'tmux_helper',
        modifier: 'control',
        keycode: 'char_t',
        mode: ['vi_normal', 'vi_insert'],
        event: [
            {
                edit: 'insertstring',
                value: ($tmux_command),
            },
            {
                send: 'Enter',
            },
        ],
    },
    {
# https://www.nushell.sh/book/line_editor.html#removing-a-default-keybinding
        modifier: 'control',
        keycode: 'char_n',
        mode: ['vi_normal', 'vi_insert'],
        event: null,
    },
    {
        name: 'history_word_or_ide_completion'
        modifier: 'control',
        keycode: 'char_n',
        mode: ['vi_normal', 'vi_insert'],
        event: {
            until: [
                { send: 'HistoryHintWordComplete' },
                { send: 'menu', name: 'ide_completion_menu' },
                { send: 'menunext' },
                { edit: 'complete' },
            ],
        },
    },
]

overlay use utils.nu

alias profiletime = echo $'loading the profile takes (timeit-profile)'
alias fennel = ^luajit ~/.local/bin/fennel
alias edit = nvr -cc split --remote-wait
alias w = wait_for_jobs
