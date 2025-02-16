use consts.nu [platform]

# create environment for pyenv
export def main []: nothing -> record<PYENV_ROOT: string, PATH: string> {
    # https://github.com/pyenv/pyenv?tab=readme-ov-file#set-up-your-shell-environment-for-pyenv
    let pyenv_root = ($env.HOME | path join '.pyenv')
    return {
        PYENV_ROOT: ($pyenv_root),
        PATH: (
            $env.PATH |
            # https://www.nushell.sh/book/configuration.html#pyenv
            if (which 'pyenv' | is-empty) {
                prepend ($pyenv_root | path join 'shims') |
                append ($pyenv_root | path join 'bin')
            } else {
                prepend (
                    ^pyenv root |
                    decode 'utf8' |
                    str trim --right |
                    path join 'shims'
                )
            }
        ),
    }
}
