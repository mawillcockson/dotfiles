LOCAL_SET_STUFF="$(set +o)"
set -x
export SSH_AUTH_SOCK="$(gpgconf --list-dir agent-ssh-socket)"
export GPG_TTY="$(tty)"
gpg-connect-agent updatestartuptty /bye
eval "${LOCAL_SET_STUFF}"
