export HOME="${HOME:-"/data/data/com.termux/files/home"}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"

init_starship() {
    if ! command -v starship &> /dev/null; then
        printf '%s\n' 'starship not found'
        return 0
    fi
    export STARSHIP_CONFIG="${XDG_CONFIG_HOME}/starship/starship.toml"
    if ! [ -r "${STARSHIP_CONFIG}" ]; then
        printf '%s\n' "${STARSHIP_CONFIG} not found:"
    fi
    if [ -z "${STARSHIP_SHELL:+"set"}" ]; then
        eval "$(starship init bash)"
    fi
}

init_atuin() {
    if ! command -v atuin &> /dev/null; then
        printf '%s\n' 'atuin not found'
        return 0
    fi
    if [ -z "${ATUIN_SESSION:+"set"}" ]; then
        eval "$(atuin init bash)"
    fi
}

alias init_ssh='eval "$(okc-ssh-agent)"'
alias init_ssh_agent='init_ssh'

# Created by `pipx` on 2022-08-14 17:26:29
export PATH="$PATH:/data/data/com.termux/files/home/.local/bin"

if [ -n "${OLD:+"set"}" ]; then
    printf '%s\n' "Environment variable 'OLD' is already in use!"
    exit 1
else
    OLD="$(pwd -P)"
    if cd ~/.cargo/bin >/dev/null 2>&1 && CARGO_BIN="$(pwd -P)"; then
        PATH="${PATH}:${CARGO_BIN}"
    fi
    cd "${OLD}"
    unset -v OLD
    unset -v CARGO_BIN
fi

if nu -e exit 2>&1 && [ -z "${DONT_USE_NU+'set'}" ]; then
    exec nu --login
fi

if [ -n "${SSH_CONNECTION:+"set"}" ]; then
    # ble.sh
    [[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --attach=none

    init_starship
    init_atuin

    # ble.sh
    # Add the following line at the end of ~/.bashrc
    [[ ${BLE_VERSION-} ]] && ble-attach

    if [ -z "${TMUX:+"set"}" ] && tmux has-session -t ssh; then
        tmux set-environment -t ssh SSH_AUTH_SOCK "${SSH_AUTH_SOCK}"
        if [ "$(tmux list-windows -t ssh | wc -l)" -eq 1 ]; then
            tmux new-window -t ssh
        fi
        tmux attach -t ssh
    fi
fi
