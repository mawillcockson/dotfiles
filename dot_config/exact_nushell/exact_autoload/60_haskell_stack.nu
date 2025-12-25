use std/log
let stack_config_yaml = ($env.XDG_CONFIG_HOME | path join 'stack' 'config.yaml')

if ($stack_config_yaml | path exists) {
    let backup_path = ($stack_config_yaml | path parse | update 'stem' {|rec| $'($rec.stem)-backup'} | path join)
    if not ($backup_path | path exists) {
        log info $'backing up Haskell Stack config to ($backup_path | to nuon)'
        cp $stack_config_yaml $backup_path
    }
    let content = open $stack_config_yaml
    $content | upsert 'local-bin-path' {|rec| $env.STACK_LOCAL_BIN_PATH } | save -f $stack_config_yaml
} | null
