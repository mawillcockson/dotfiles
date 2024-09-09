if ! command -v command; then
    echo 'builtin command -v is not POSIX compliant'
    echo 'this is the case for posh < v0.14.1, for example'
    exit 1
fi

. /usr/local/share/sh/log.sh

need_commands() {
    if test "$#" -lt 1; then
        error "need at least one command name"
    fi

    for name in "$@"; do
        if ! command -v "${name}" > /dev/null 2>&1; then
            log ERROR "${name}: command not found"
            MISSING='true'
        fi
    done

    if test -n "${MISSING:+"set"}"; then
        error "missing required commands"
    fi
    return 0
}
