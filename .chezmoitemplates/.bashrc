# {{ if .chezmoi.os | eq "android" }}
SUB_PREFIX="${PREFIX:+"$(dirname "${PREFIX}")"}"
export HOME="${HOME:-"${SUB_PREFIX-}/home"}"
# {{ else }}
export HOME="${HOME:-"/home/${USER:-"$(id -un)"}"}"
# {{ end }}
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"

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

# Created by `pipx` on 2022-08-14 17:26:29
# modified by me
export PATH="${PATH}:${HOME}/.local/bin"

if [ -n "${OLD:+"set"}" ]; then
    printf '%s\n' "Environment variable 'OLD' is already in use!"
else
    OLD="$(pwd -P)"
    if cd ~/.cargo/bin >/dev/null 2>&1 && CARGO_BIN="$(pwd -P)"; then
        PATH="${PATH}:${CARGO_BIN}"
    fi
    cd "${OLD}" || echo "cannot cd into \$OLD -> \"${OLD}\""
    unset -v OLD || true
    unset -v CARGO_BIN || true
fi

if command -v nu >/dev/null 2>&1 && nu -e exit 2>&1 && [ -n "${PLEASE_USE_NU+"set"}" ]; then
    exec nu --login
fi

init_starship
init_atuin

# from:
# https://github.com/mawillcockson/dotfiles/blob/d9cd2ef8ca9293c8f7b86de8c5b23246135b6f5c/dotfiles/.profile
if [ -d /etc/profile.d ] && [ -z "${ALREADY_SOURCED_SYSTEM_PROFILE_D+"set"}" ]; then
    ALREADY_SOURCED_SYSTEM_PROFILE_D="true"
    export ALREADY_SOURCED_SYSTEM_PROFILE_D
    for file in /etc/profile.d/*.sh; do
        if ! . "$file"; then
            printf '%s did not load correctly\n' "$file"
        fi
    done
fi

if [ -d "${HOME}/.profile.d" ] && [ -z "${ALREADY_SOURCED_USER_PROFILE_D+"set"}" ]; then
    ALREADY_SOURCED_USER_PROFILE_D="true"
    export ALREADY_SOURCED_USER_PROFILE_D
    for file in "${HOME}/.profile.d"/*.sh; do
        if ! . "$file"; then
            printf '%s did not load correctly\n' "$file"
        fi
    done
fi
