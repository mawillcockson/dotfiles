#!/data/data/com.termux/files/usr/bin/sh
set -eu

PROFILE_D='/data/data/com.termux/files/etc/profile.d'
FILE="${PROFILE_D}/set_XDG_CONFIG_HOME.sh"
touch "${FILE}"
chmod a+x "${FILE}"

DATA='XDG_CONFIG_HOME='"${XDG_CONFIG_HOME}"'
export XDG_CONFIG_HOME'

printf '%s\n' "${DATA}" > "${FILE}"
