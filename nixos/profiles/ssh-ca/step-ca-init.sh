#!/bin/sh
set -eu

MARKER="${STATE_DIRECTORY:?"\$STATE_DIRECTORY not set"}/~step-ca-init.sh_was_run"
if test -f "${MARKER}"; then
    printf '%s\n' \
        "marker file already exists: ${MARKER}" \
        "exiting early"
    exit 0
fi

out="${out:-"${STATE_DIRECTORY}"}"
if test -d "${out:?}"; then
    rm -rf "${out:?}"/* "${out:?}"/*.*
fi
mkdir -p "${out}"
chmod u=rw,go= "${STATE_DIRECTORY}"
PASSWORD_FILE="${CREDENTIALS_DIRECTORY:?"\$CREDENTIALS_DIRECTORY not set"}/step-ca_password"

ls -alhR "${STATE_DIRECTORY}/" "$out/"

# NOTE::IMPROVEMENT step ca creates ecdsa-sha2-nistp256 keys for the root ca,
# intermediate ca, host, and user keys
# It would be nice to use Ed25519 everywhere.
STEPPATH="${STEPPATH:-"$out"}"
export STEPPATH
step ca init \
    --ssh \
    --deployment-type=standalone \
    --name=pki.test \
    --dns=root-ca.test \
    --address=:443 \
    --provisioner=test@test.test \
    --password-file="${PASSWORD_FILE}" #\
    # if not given, --password-file is used
    #--provisioner-password-file="${PASSWORD_FILE}"

#touch "${MARKER}"
#chown "$(id -un):$(id -gn)" "${MARKER}"
#chmod a= "${MARKER}"
