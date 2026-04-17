#!/usr/bin/env nix
#! nix env shell nixpkgs#step-cli nixpkgs#step-ca nixpkgs#jq nixpkgs#dash --command dash
set -eu
STEPPATH=./outputs/step-cli
export STEPPATH
rm -r "$STEPPATH" || true
mkdir -p "$STEPPATH/secrets/" "$STEPPATH/templates/"
echo 'insecure root ca password' > "$STEPPATH/secrets/root-ca-password.txt"
#echo 'insecure intermediate ca password' > "$STEPPATH/secrets/intermediate-ca-password.txt"
cp -v "$STEPPATH/secrets/root-ca-password.txt" "$STEPPATH/secrets/intermediate-ca-password.txt"
echo 'insecure provisioner password' > "$STEPPATH/secrets/provisioner-password.txt"
step ca init \
    --deployment-type=standalone \
    --ssh \
    --acme \
    --name="test pki" \
    --provisioner="first provisioner" \
    --dns=localhost \
    --address='[::0]:52000' \
    --password-file="$STEPPATH/secrets/root-ca-password.txt" \
    --provisioner-password-file="$STEPPATH/secrets/provisioner-password.txt"

printf '%s\n' '{
    "subject": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign", "digitalSignature"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 0
    }
}' > "$STEPPATH/templates/intermediate-ca.tmpl"
cat "$STEPPATH/templates/intermediate-ca.tmpl"
step certificate create \
    "test pki Intermediate CA" \
    "$STEPPATH/certs/intermediate_ca.crt" \
    --key="$STEPPATH/secrets/intermediate_ca_key" \
    --force \
    --password-file="$STEPPATH/secrets/intermediate-ca-password.txt" \
    --template="$STEPPATH/templates/intermediate-ca.tmpl" \
    --ca="$STEPPATH/certs/root_ca.crt" \
    --ca-key="$STEPPATH/secrets/root_ca_key" \
    --ca-password-file="$STEPPATH/secrets/root-ca-password.txt"

#echo "insecure" > "$STEPPATH/secrets/x5c_intermediate_key_password"
#step certificate create \
#    "X5C Intermediate CA" \
#    "$STEPPATH/certs/x5c_intermediate.crt" \
#    "$STEPPATH/secrets/x5c_intermediate_key" \
#    --kty=OKP --curve=Ed25519 \
#    --password-file="$STEPPATH/secrets/x5c_intermediate_key_password" \
#    --profile=intermediate-ca \
#    --ca="$STEPPATH/certs/root_ca.crt" \
#    --ca-key="$STEPPATH/secrets/root_ca_key" \
#    --ca-password-file="$STEPPATH/secrets/root-ca-password.txt"
#step certificate inspect \
#  "$STEPPATH/certs/x5c_intermediate.crt" \
#  --roots="$STEPPATH/certs/root_ca.crt"
#step ca provisioner add \
#    x5c \
#    --type=X5C \
#    --x5c-roots="$STEPPATH/certs/x5c_intermediate.crt" \
#    --ca-config="$STEPPATH/config/ca.json"
step ca provisioner add \
    x5c \
    --type=X5C \
    --x5c-roots="$STEPPATH/certs/root_ca.crt" \
    --ca-config="$STEPPATH/config/ca.json"

cat "$STEPPATH/certs/intermediate_ca.crt" "$STEPPATH/certs/root_ca.crt" > "$STEPPATH/certs/intermediate_and_root.crt"

if ! NEW_CONFIG="$(jq --exit-status --compact-output \
    '. | del(.templates) |
    setpath(
        ["authority", "provisioners"];
        .authority.provisioners | map(select(.type != "JWK"))
    )' "$STEPPATH/config/ca.json")"
then
    printf '%s\n' '--ERROR-- jq encountered an error'
    exit 1
else
    printf '%s\n' "$NEW_CONFIG" > "$STEPPATH/config/ca.json"
fi

step-ca "$STEPPATH/config/ca.json" --password-file="$STEPPATH/secrets/root-ca-password.txt" &
STEP_CA_PID="$!"
while ! curl --cacert "$STEPPATH/certs/root_ca.crt" https://localhost:52000; do
    printf '%s' '.'
    sleep 0.5
done
printf '\n'

cleanup() {
    printf '%s\n' '--INFO-- killing step-ca'
    while kill -s INT "$STEP_CA_PID"; do
        printf '%s' '.'
        sleep 1
    done
    printf '\n'
    trap - TERM EXIT QUIT INT
}
trap 'cleanup' TERM EXIT QUIT INT

TOKEN="$(step ca token \
    "test.example.com" \
    --ssh \
    --host \
    --provisioner=x5c \
    --x5c-cert="$STEPPATH/certs/intermediate_and_root.crt" \
    --x5c-key="$STEPPATH/secrets/intermediate_ca_key" \
    --password-file=./outputs/step-cli/secrets/intermediate-ca-password.txt \
    --ca-url=https://localhost:52000 \
    --root=./outputs/step-cli/certs/root_ca.crt
)"
step ssh certificate \
    "test id" \
    "$STEPPATH/secrets/test_ssh_host_ed25519" \
    --no-password --insecure \
    --provisioner=x5c \
    --console \
    --host \
    --host-id=machine \
    --principal \
    "test.example.com" \
    --kty=OKP --curve=Ed25519 \
    --comment $'host@(date now | format date "%+")' \
    --x5c-cert="$STEPPATH/certs/intermediate_and_root.crt" \
    --x5c-key="$STEPPATH/secrets/intermediate_ca_key" \
    --no-agent \
    --ca-url=https://localhost:52000 \
    --token "$TOKEN"

mv -v "$STEPPATH/secrets/test_ssh_host_ed25519-cert.pub" "$STEPPATH/certs/"
mv -v "$STEPPATH/secrets/test_ssh_host_ed25519.pub" "$STEPPATH/certs/"
step ssh inspect "$STEPPATH/certs/test_ssh_host_ed25519-cert.pub"

exit 0
