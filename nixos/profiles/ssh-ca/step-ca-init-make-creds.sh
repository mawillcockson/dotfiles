#!/bin/sh
set -eu

MARKER="${STATE_DIRECTORY:?"\$STATE_DIRECTORY not set"}/~step-ca-init-make-creds.sh_was_run"
if test -f "$MARKER"; then
    printf '%s\n' \
        "marker file already exists: $MARKER" \
        "exiting early"
    exit 0
fi

umask 377
CREDENTIALS_DIRECTORY=/etc/credstore.encrypted
mkdir -p "${CREDENTIALS_DIRECTORY}"
PASSWORD_FILE="${CREDENTIALS_DIRECTORY}/step-ca_password"
printf '%s' 'insecure' | systemd-creds encrypt --with-key=auto - "${PASSWORD_FILE}"
chown root:root -R "${CREDENTIALS_DIRECTORY}"
chmod u=r,go= -R "${CREDENTIALS_DIRECTORY}"

#touch "${MARKER}"
#chown "$(id -un):$(id -gn)" "${MARKER}"
#chmod a= "${MARKER}"
