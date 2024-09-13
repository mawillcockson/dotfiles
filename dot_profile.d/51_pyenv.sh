if ! command -v pyenv > /dev/null 2>&1; then
    PATH="${PATH}:${PYENV_ROOT:-"${HOME}/.pyenv"}/bin"
fi
if command -v pyenv; then
    if ! eval "$(pyenv init --path)"; then
        printf 'problem initializing pyenv\n'
    fi
else
    printf 'cannot find pyenv!\n'
fi
