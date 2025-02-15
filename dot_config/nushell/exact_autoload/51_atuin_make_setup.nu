if (which atuin | is-not-empty) {
    use consts.nu [autoload]
    # currently, atuin can automatically run the command when <Enter> is
    # pressed in other shells, but can't in nu
    # https://github.com/atuinsh/atuin/issues/1392
    # this disables atuin filling in for the up arrow
    ^atuin init --disable-up-arrow nu | save -f ($autoload | path join '52_generated_atuin_setup.nu')
} else {
    use std/log
    log warning 'atuin executable not found'
}
