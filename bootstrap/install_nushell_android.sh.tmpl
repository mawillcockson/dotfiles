#!/data/data/com.termux/files/usr/bin/sh
set -eu

if command -v nu >/dev/null 2>&1; then
    echo 'nu already installed'
else
    pkg update
    pkg install nushell || pkg upgrade nushell
fi

if ! command -v nu >/dev/null 2>&1; then
    echo 'could not install nu'
    exit 1
fi

#{{ with .minimum_nu_version }}
exec nu -c '
use std [log]
if (
    version |
    select major minor patch |
    into int major minor patch |
    (
        ($in.major >= {{ .major }})
        and
        ($in.minor >= {{ .minor }})
        and
        ($in.patch >= {{ .patch }})
    )
) {
    log info "nu version is new enough"
    exit 0
} else {
    log error "nu version is not new enough"
    exit 1
}'
#{{ end }}
