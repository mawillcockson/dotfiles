#!/bin/sh
set -eu

mkdir -p "$out/secrets"
PASSWORD_FILE="$out/secrets/password.txt"
printf '%s' 'insecure' > "$PASSWORD_FILE"

STEPPATH="$out"
export STEPPATH
step ca init \
    --ssh \
    --deployment-type=standalone \
    --name=pki.test \
    --dns=root-ca.test \
    --address=:443 \
    --provisioner=test@test.test \
    --password-file="$PASSWORD_FILE" #\
    #--provisioner-password-file="$PASSWORD_FILE"
