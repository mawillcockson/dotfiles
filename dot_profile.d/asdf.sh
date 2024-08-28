if [ -r "${HOME}/.asdf/asdf.sh" ]; then
    if ! . "${HOME}/.asdf/asdf.sh"; then
        printf 'problem loading asdf\n'
    fi
    if [ "${SHELL##*/}" = "bash" ] && ! . "${HOME}/.asdf/completions/asdf.bash"; then
        printf 'problem loading asdf completions\n'
    fi
fi
