set -eu
STEPPATH=./outputs/step-cli
export STEPPATH
rm -r "$STEPPATH" || true
mkdir -p "$STEPPATH/secrets/"
echo 'insecure root ca password' > "$STEPPATH/secrets/ca-password.txt"
echo 'insecure provisioner password' > "$STEPPATH/secrets/provisioner-password.txt"
step ca init \
    --deployment-type=standalone \
    --ssh \
    --acme \
    --name="test pki" \
    --provisioner="first provisioner" \
    --dns=myLaptop.local \
    --address=[::0]:52000 \
    --password-file="$STEPPATH/secrets/ca-password.txt" \
    --provisioner-password-file="$STEPPATH/secrets/provisioner-password.txt"
