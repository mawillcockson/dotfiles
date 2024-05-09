# NOTE: when ready, can use `scope commands` to check if `package` is
# available, and add/check what's available
#let comparisons = [
#    ['name', 'command', 'variable'];
#    ['$default_package_manager_data_path', (package manager data-path), (ls --all --full-paths $default_package_manager_data_path | get 0.name)],
#    ['$default_package_data_path', (package data data-path), (ls --all --full-paths $default_package_data_path | get 0.name)],
#    ['$default_package_customs_path', (package data customs-data-path), (ls --all --full-paths $default_package_customs_path | get 0.name)],
#]
#for $rec in $comparisons {
#    try {
#        std assert equal ($rec.command) ($rec.variable)
#    } catch {
#        log error $"($rec.name) is out of sync with command:\n($rec.command)\n($rec.variable)"
#    }
#}
#export-env {
#    # NOTE::PERF currently too slow
#    # different architecture would drastically speed it up
#    #try {
#    #    package manager save-data | load-env
#    #} catch {
#    #    log error 'problem when saving package manager data'
#    #}
#    #try {
#    #    package data save-data | load-env
#    #} catch {
#    #    log error 'problem when saving package data'
#    #}
#}
