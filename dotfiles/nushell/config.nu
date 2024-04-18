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
    | upsert history.max_size 10_000_000
    | upsert history.file_format 'sqlite'
    | upsert buffer_editor (
        if ('NVIM' in $env) and (which nvr | is-not-empty) {
            'nvr -cc split --remote-wait'
        } else {''}
    )
    | upsert edit_mode 'vi'
)

overlay use clipboard.nu
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
    # try {
    #     package manager save-data | load-env
    # } catch {
    #     log error 'problem when saving package manager data'
    # }
    # try {
    #     package data save-data | load-env
    # } catch {
    #     log error 'problem when saving package data'
    # }
}

alias dt = date my-format

# Atuin should be able to handle a lot of history, so don't cull based on
# number of entries
# let opopo = {
#     history.max_size: 10_000_000
#     show_banner: false
# }
