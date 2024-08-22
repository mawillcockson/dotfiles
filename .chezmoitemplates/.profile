# {{ if .chezmoi.os | eq "android" }}
SUB_PREFIX="${PREFIX:+"$(dirname "${PREFIX}")"}"
export HOME="${HOME:-"${SUB_PREFIX-}/home"}"
# {{ else }}
export HOME="${HOME:-"/home/${USER:-"$(id -un)"}"}"
# {{ end }}
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"

# from:
# https://github.com/mawillcockson/dotfiles/blob/d9cd2ef8ca9293c8f7b86de8c5b23246135b6f5c/dotfiles/.profile
ALREADY_SOURCED_USER_PROFILE="true"
export ALREADY_SOURCED_USER_PROFILE
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
