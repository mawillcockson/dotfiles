if [ -z "${ALREADY_SOURCED_USER_PROFILE+"set"}" ] && [ -r ~/.profile ]; then
    if ! . ~/.profile; then
        echo "problem with ~/.profile"
    fi
fi

init_starship() {
    if ! command -v starship >/dev/null 2>&1; then
        printf '%s\n' 'starship not found'
        return 0
    fi
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
    if ! [ -r "${STARSHIP_CONFIG}" ]; then
        printf '%s\n' "${STARSHIP_CONFIG} not found:"
    fi
    if [ -z "${STARSHIP_SHELL:+"set"}" ]; then
        if ! STARSHIP_INIT="$(starship init bash)"; then
            echo 'problem starting starship'
        else
            eval "${STARSHIP_INIT}"
        fi
    fi
}

init_atuin() {
    if ! command -v atuin >/dev/null 2>&1; then
        printf '%s\n' 'atuin not found'
        return 0
    fi
    if [ -z "${ATUIN_SESSION:+"set"}" ]; then
        if ! ATUIN_INIT="$(atuin init bash)"; then
            echo 'problem starting atuin'
        else
            eval "${ATUIN_INIT}"
        fi
    fi
}

alias init_ssh='eval "$(okc-ssh-agent)"'
alias init_ssh_agent='init_ssh'

if [ -n "${PLEASE_USE_NU+"set"}" ] && command -v nu >/dev/null 2>&1 && nu -e exit 2>&1; then
    exec nu --login
fi

case "$-" in
*i*)
    # shell is interactive
    init_starship
    init_atuin

    BASH_PREEXEC_FILE="${XDG_DATA_HOME:-"${HOME?"\$HOME not defined"}"/.local/share}/bash-preexec/.bash-preexec.sh"
    # only use .bash-preexec.sh when ble.sh isn't present; otherwise use
    # ble.sh's implementation:
    # https://github.com/akinomyoga/ble.sh/wiki/Performance#18-debug-trap
    if test -n "${BLE_VERSION-}"; then
        # .bash-preexec is not really needed by anything I use, that doesn't
        # already use ble.sh, so if it's loaded, we're good
        : ble-import integration/bash-preexec
    elif test -f "${BASH_PREEXEC_FILE}"; then
        if ! . "${BASH_PREEXEC_FILE}"; then
            printf 'problem loading .bash-preexec.sh!\n'
        fi
    fi
    unset -v BASH_PREEXEC_FILE || true
    ;;
esac
