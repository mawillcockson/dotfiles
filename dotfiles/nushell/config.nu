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
            'nvr -cc split --remote-wait'
        } else {''}
    )
    | upsert edit_mode 'vi'
    | upsert show_banner false
)

overlay use --prefix clipboard.nu
overlay use utils.nu
overlay use --prefix std

# package module
overlay use --prefix --reload package
overlay use --prefix --reload $default_package_manager_data_path as 'package manager data'
overlay use --prefix --reload $default_package_customs_path as 'package customs data'
let comparisons = [
    ['name', 'command', 'variable'];
    ['$default_package_manager_data_path', (package manager data-path), (ls --all --full-paths $default_package_manager_data_path | get 0.name)],
    ['$default_package_data_path', (package data data-path), (ls --all --full-paths $default_package_data_path | get 0.name)],
    ['$default_package_customs_path', (package data customs-data-path), (ls --all --full-paths $default_package_customs_path | get 0.name)],
]
for $rec in $comparisons {
    try {
        std assert equal ($rec.command) ($rec.variable)
    } catch {
        log error $"($rec.name) is out of sync with command:\n($rec.command)\n($rec.variable)"
    }
}
export-env {
    # NOTE::PERF currently too slow
    # different architecture would drastically speed it up
    #try {
    #    package manager save-data | load-env
    #} catch {
    #    log error 'problem when saving package manager data'
    #}
    #try {
    #    package data save-data | load-env
    #} catch {
    #    log error 'problem when saving package data'
    #}
}

alias dt = date my-format
alias profiletime = echo $'loading the profile takes (timeit-profile)'

stor open | query db `
CREATE TABLE IF NOT EXISTS state (
    name TEXT PRIMARY KEY,
    value TEXT
) STRICT`
stor open | query db `
INSERT INTO state (name, value)
    VALUES ('banner_shown', 'false')`
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
}
