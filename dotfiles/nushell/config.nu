const scripts = $"($nu.default-config-dir)/scripts"
const generated = $"($scripts)/generated"
const default_config = $"($generated)/default_config.nu"
source $default_config

const postconfig = $"($generated)/postconfig.nu"
# because this is a parser directive, it can't be guarded with `if path
# exists`: if it exists, it'll be sourced, and if it doesn't, the whole file
# can't be read
source $postconfig

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
)

overlay use utils.nu
overlay use --prefix dt.nu

alias profiletime = echo $'loading the profile takes (timeit-profile)'
alias fennel = ^luajit ~/.local/bin/fennel

let commands = (scope commands | get name)
if $nu.is-interactive and ('my-banner' in $commands) {
# NOTE::ABOMINATION
    stor open | query db `
    CREATE TABLE IF NOT EXISTS state (
        name TEXT PRIMARY KEY,
        value TEXT
    ) STRICT`
    stor open | query db `
    INSERT INTO state (name, value)
        VALUES ('banner_shown', 'false'),
               ('commandline_edited', 'false')`
    let original_prompt = $env.PROMPT_COMMAND
    $env.PROMPT_COMMAND = {||
        if (
            stor open
            | query db `SELECT value FROM state WHERE name = 'banner_shown'`
            | get value.0
        ) != 'true' {
            my-banner
            stor open | query db `UPDATE state SET value = 'true' WHERE name = 'banner_shown'`
        }
        do $original_prompt
        if (
            stor open |
            query db `SELECT value FROM state WHERE name = 'commandline_edited'` |
            get value.0
        ) != 'true' {
            if (which 'tmux' | is-not-empty) {
                if ('TMUX' not-in $env) and ((^tmux has-session | complete | get exit_code) == 0) {
                    if (^tmux has-session -t ssh | complete | get exit_code) == 0 {
                        commandline edit --replace 'tmux attach -t ssh'
                    } else {
                        commandline edit --replace 'tmux attach -d'
                    }
                }
                use std [log]
                log info 'tried editing commandline'
                commandline edit --replace 'try { tmux attach -d } catch { tmux -f ~/.tmux.conf }'
            }
            stor open | query db `UPDATE state SET value = 'true' WHERE name = 'commandline_edited'`
        }
    }
}
