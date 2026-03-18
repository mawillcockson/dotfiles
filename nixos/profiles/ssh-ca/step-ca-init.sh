#!/bin/sh
set -eu

# shellcheck disable=SC1090
. "${LOG_SH:?"\$LOG_SH not set"}"

STATE_DIRECTORY="${STATE_DIRECTORY:?"\$STATE_DIRECTORY not set"}"
DEBUG="${DEBUG:-"no"}"
MARKER="${STATE_DIRECTORY}/~step-ca-init.sh_was_run"
if test -f "${MARKER}"; then
    printf '%s\n' \
        "marker file already exists: ${MARKER}" \
        "exiting early"
    exit 0
fi

if test "$DEBUG" = yes; then
    echo "current user is:"
    id
    printf "\$STATE_DIRECTORY is %s" "${STATE_DIRECTORY}"
    set -x
    ls -alhR "${STATE_DIRECTORY}/"
    ls -alnhR "${STATE_DIRECTORY}/"
    set +x
fi

if test "$DEBUG" = yes; then
    echo 'clearing previous setup'
    find -H "${STATE_DIRECTORY}" -mindepth 1 -print '(' -delete -o -printf 'could not delete: %P\n' ')'
else
    find -H "${STATE_DIRECTORY}" -mindepth 1 -delete
fi

CA_JSON="${CONFIG_DIR:-"/etc/smallstep"}/ca.json"
if ! test -f "${CA_JSON}"; then
    error "\$CA_JSON expected and not found at -> ${CA_JSON}"
fi
if ! SSH_HOST_KEY="$(jq --raw-output --exit-status '.ssh.hostKey' "${CA_JSON}")"; then
    error "jq could not find host key path in ca.json -> ${CA_JSON}"
fi
if ! SSH_USER_KEY="$(jq --raw-output --exit-status '.ssh.userKey' "${CA_JSON}")"; then
    error "jq could not find user key path in ca.json -> ${CA_JSON}"
fi
if ! ROOT_CERT="$(jq --raw-output --exit-status '.root' "${CA_JSON}")"; then
    error "jq could not find root cert path in ca.json -> ${CA_JSON}"
fi
if ! INTERMEDIATE_CERT="$(jq --raw-output --exit-status '.crt' "${CA_JSON}")"; then
    error "jq could not find intermediate cert path in ca.json -> ${CA_JSON}"
fi
if ! INTERMEDIATE_KEY="$(jq --raw-output --exit-status '.key' "${CA_JSON}")"; then
    error "jq could not find intermediate key path in ca.json -> ${CA_JSON}"
fi

mkdir -v "${STATE_DIRECTORY}/db"
chmod --changes u=rwX,go= "${STATE_DIRECTORY}"

STEPPATH="${STEPPATH:-"$STATE_DIRECTORY"}"
export STEPPATH
info "\$STEPPATH -> ${STEPPATH}"

SECRETS="${STATE_DIRECTORY}/secrets"
mkdir -v "${SECRETS}"

PASSWORD_FILE="${CREDENTIALS_DIRECTORY:?"\$CREDENTIALS_DIRECTORY not set"}/step-ca_password"
info "\$PASSWORD_FILE -> ${PASSWORD_FILE}"

DATETIME="$(date --iso-8601=seconds)"
info "\$DATETIME -> ${DATETIME}"

CERTS_DIR="${STEPPATH}/certs"
info "placing certificates and public keys in \$CERTS_DIR -> ${CERTS_DIR}"
mkdir -v "${CERTS_DIR}"

ssh-keygen \
    -t ed25519 \
    -C "intermediate CA host key @ ${DATETIME}" \
    -f "${SSH_HOST_KEY}" \
    -N "$(cat "${PASSWORD_FILE}")"
info 'removing .pub file for host key'
mv -v "${SSH_HOST_KEY}.pub" "${CERTS_DIR}/"
ssh-keygen \
    -t ed25519 \
    -C "intermediate CA user key ${DATETIME}" \
    -f "${SSH_USER_KEY}" \
    -N "$(cat "${PASSWORD_FILE}")"
info 'moving .pub file for user key to expected place'
mv -v "${SSH_USER_KEY}.pub" "${CERTS_DIR}/"

ROOT_KEY="${SECRETS}/root_ca_key"
info "creating a root ca certificate at -> ${ROOT_CERT}"
info "will be storing root key at -> ${ROOT_KEY}"
step certificate create \
    'test pki Root CA' \
    "${ROOT_CERT}" \
    "${ROOT_KEY}" \
    --kty=OKP \
    --profile=root-ca \
    --password-file="${PASSWORD_FILE}" \
    --not-before=-10m \
    --not-after="$((24 * 365))h"

info "creating an intermediate ca certificate at -> ${INTERMEDIATE_CERT}"
info "will be storing intermediate key at -> ${INTERMEDIATE_KEY}"
step certificate create \
    'test pki Intermediate CA' \
    "${INTERMEDIATE_CERT}" \
    "${INTERMEDIATE_KEY}" \
    --kty=OKP \
    --profile=intermediate-ca \
    --password-file="${PASSWORD_FILE}" \
    --not-before=-10m \
    --not-after="$((24 * 365))h" \
    --ca="${ROOT_CERT}" \
    --ca-key="${ROOT_KEY}" \
    --ca-password-file="${PASSWORD_FILE}"

# NOTE: disable creating marker file, so 
#touch "${MARKER}"
#chown "$(id -un):$(id -gn)" "${MARKER}"
#chmod a= "${MARKER}"

## NOTE::IMPROVEMENT step ca creates ecdsa-sha2-nistp256 keys for the root ca,
## intermediate ca, host, and user keys
## It would be nice to use Ed25519 everywhere.
#step ca init \
#    --ssh \
#    --deployment-type=standalone \
#    --name=pki.test \
#    --dns=root-ca.test \
#    --address=:443 \
#    --provisioner=test@test.test \
#    --password-file="${PASSWORD_FILE}" #\
#    # if not given, --password-file is used
#    #--provisioner-password-file="${PASSWORD_FILE}"
