if [ -r ~/.profile ] && [ -z "${ALREADY_SOURCED_USER_PROFILE+"set"}" ]; then
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

if command -v nu >/dev/null 2>&1 && nu -e exit 2>&1 && [ -n "${PLEASE_USE_NU+"set"}" ]; then
    exec nu --login
fi

init_starship
init_atuin
