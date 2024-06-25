const scripts = $"($nu.default-config-dir)/scripts"
const generated = $"($scripts)/generated"
const default_config = $"($generated)/default_config.nu"
source $default_config

const postconfig = $"($generated)/postconfig.nu"
# because this is a parser directive, it can't be guarded with `if path
# exists`: if it exists, it'll be sourced, and if it doesn't, the whole file
# can't be read
source $postconfig

let banner_once = r#'
    my-banner
    $env.config.hooks.pre_prompt = (
        $env.config.hooks.pre_prompt |
        filter {|it| $it != {code: $banner_once} }
    )
'# #'

# NOTE: this still doesn't work
let tmux_once = r##'
    # $env.NU_LOG_LEVEL = 'debug'
    if (which 'tmux' | is-not-empty) and ('TMUX' not-in $env) {
        let has_session = ((^tmux has-session | complete | get exit_code) == 0)

        if ($has_session) == true {
            let has_ssh = ((^tmux has-session -t ssh | complete | get exit_code) == 0)
            if ($has_ssh) == true {
                commandline edit --replace 'tmux attach -t ssh'
            } else {
                commandline edit --replace 'tmux attach -d'
            }
        } else {
            match ($nu.os-info.name) {
                'android' => { commandline edit --replace 'tmux -f ~/.tmux.conf' },
                _ => { commandline edit --replace 'tmux' },
            }
        }
    } else if (which 'tmux' | is-not-empty) {
        print 'tmux already running'
    } else {
        commandline edit --replace 'nu -c `use package; package install tmux`'
    }

    $env.config.keybindings = (
        $env.config.keybindings |
        filter {|it| ($it | get name?) != 'tmux_helper' }
    )
'## ##'

$env.config = (
    $env.config
    # NOTE::BUG There's a note in `config nu --default` that the session has
    # to be reloaded in order for history.* to take effect, and they don't seem to
    # be taking effect
# Atuin should be able to handle a lot of history, so don't cull based on
# number of entries
    | upsert history.max_size 10_000_000
    | upsert history.file_format 'sqlite'
    | upsert buffer_editor (
        if ('NVIM' in $env) and (which nvr | is-not-empty) {
            [nvr -cc split --remote-wait]
        } else {''}
    )
    | upsert edit_mode 'vi'
    | upsert show_banner false
    | upsert hooks.pre_prompt {|config|
        $config |
        get hooks.pre_prompt? |
        default [] |
        append [
            {code: ($banner_once)},
        ]
    }
    | upsert keybindings {|config|
        $config |
        get keybindings? |
        default [] |
        append [
            {
                name: 'tmux_helper',
                modifier: 'control',
                keycode: 'char_g',
                mode: ['vi_normal', 'vi_insert'],
                event: [
                    {
                        send: 'executehostcommand',
                        cmd: ($tmux_once),
                    },
                    {send: 'Enter'},
                ],
            },
        ]
    }
)

overlay use utils.nu
overlay use --prefix dt.nu

alias profiletime = echo $'loading the profile takes (timeit-profile)'
alias fennel = ^luajit ~/.local/bin/fennel
