use std [log]
use consts.nu [platform]

# configure the environment for pyenv
export def --env main [] {
    # https://github.com/pyenv/pyenv?tab=readme-ov-file#set-up-your-shell-environment-for-pyenv
    $env.PYENV_ROOT = ($env.HOME | path join '.pyenv')

    $env.PATH = (
        $env |
        get PATH? Path? |
        first |
        if ($in | describe | str replace --regex '<.*' '') == 'string' {
            $in | split row (char env_sep)
        } else {$in} |
        # https://www.nushell.sh/book/configuration.html#pyenv
        if (which 'pyenv' | is-empty) {
            $in |
            prepend ($env.PYENV_ROOT | path join 'shims') |
            append ($env.PYENV_ROOT | path join 'bin')
        } else {
            $in |
            prepend (
                ^pyenv root |
                decode 'utf8' |
                str trim --right |
                path join 'shims'
            )
        } |
        uniq
    )
}
