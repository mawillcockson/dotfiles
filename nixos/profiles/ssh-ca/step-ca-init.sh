{pkgs, ...}:
pkgs.runCommand "make-test-step-ca-init"
{
  nativeBuildInputs = [
    pkgs.step-ca
    pkgs.step-cli
  ];
}
''
  mkdir -p "$out/secrets"
  STEPPATH="$out"
  export STEPPATH
  PASSWORD_FILE="$out/secrets/password.txt"
  printf '%s' 'insecure' > "$PASSWORD_FILE"
  step ca init \
    --ssh \
    --deployment-type=standalone \
    --name=pki.test \
    --dns=root-ca.test \
    --address=:443 \
    --provisioner=test@test.test \
    --password-file="$PASSWORD_FILE" #\
    #--provisioner-password-file="$PASSWORD_FILE"
''
