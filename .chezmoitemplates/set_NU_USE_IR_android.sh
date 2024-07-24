#!/data/data/com.termux/files/usr/bin/sh
set -eu

PROFILE_D="${PREFIX}/etc/profile.d"
FILE="${PROFILE_D}/set_NU_USE_IR.sh"
touch "${FILE}"
chmod a+x "${FILE}"

DATA='NU_USE_IR=1
export NU_USE_IR'

printf '%s\n' "${DATA}" > "${FILE}"
