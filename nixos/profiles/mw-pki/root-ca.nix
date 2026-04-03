{
  self,
  config,
  pkgs,
  lib,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  shell-support = {
    log-sh = self.packages.${system}.log-sh;
  };
  cfg = config.services.mw-pki.rootCA;
  constants = import ./constants.nix;
  inherit (constants) configDir CREDENTIALS_DIRECTORY;
  # similar to the note for CREDENTIALS_DIRECTORY in constants.nix, this is
  # checked in `mw-pki-rootCA-make-certs-and-secrets.service`
  STATE_DIRECTORY = "/var/lib/${config.systemd.services.mw-pki-rootCA.name}";
  # canonicalize it here instead of using `basename` in the script, so it's
  # always the same
  rootCAKeyPasswordCredentialName = baseNameOf cfg.rootCAKeyPasswordPath;
  # this name is chosen based on the description of how secrets are named
  # if a directory is given for the path argument:
  # from <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#LoadCredential=ID:PATH>:
  # If an absolute path referring to a directory is specified, every file
  # in that directory (recursively) will be loaded as a separate
  # credential. The ID for each credential will be the provided ID
  # suffixed with "_$FILENAME" (e.g., "Key_file1"). When loading from a
  # directory, symlinks will be ignored.
  LoadCredentialEncrypted = "${rootCAKeyPasswordCredentialName}:${cfg.rootCAKeyPasswordPath}";

  settingsFormat = pkgs.formats.json {};
  configFile = let
    cfg = config.services.step-ca;
  in
    settingsFormat.generate "ca.json" (
      cfg.settings
      // {
        address = cfg.address + ":" + toString cfg.port;
      }
    );
in {
  options.services.mw-pki.rootCA = {
    enable = lib.mkEnableOption "rootCA";
    insecure = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "whether to generate a root key and cert using a plaintext password, or load them from sops-nix";
      example = lib.literalExpression "true";
    };
    rootCAKeyPasswordPath = lib.mkOption {
      type = lib.types.externalPath;
      default = "${CREDENTIALS_DIRECTORY}/mw-pki/rootCAKeyPassword";
      description = "where the password for the root ca key will be stored; this is encrypted with systemd-creds";
      example = lib.literalExpression "/etc/credstore.encrypted/step-ca-root-key-password";
    };
  };
  config = lib.mkIf (cfg.enable) {
    # configuration file indirection is needed to support reloading
    environment.etc."smallstep/ca.json".source = configFile;

    # NOTE::IMPROVEMENT I'm overriding instead of `pkgs.writeTextFile`, because
    # I feel the latter would be an import-from-derivation? Regardless, I think
    # this build may be able to be sped up by overriding the build phase to be
    # nothing, as the file we want just needs to be unpacked, and then
    # installed. Also, the check phase would have to be overridden
    #
    # grab the same upstream package used by services.step-ca, and override the
    # build step that places the systemd service file in place, so I can rename
    # it, and override the service that has the name of my choosing
    systemd.packages = [
      (config.services.step-ca.package.overrideAttrs (
        finalAttrs: previousAttrs: {
          postInstall =
            lib.throwIf
            (
              (lib.strings.trim previousAttrs.postInstall)
              != "install -Dm444 -t $out/lib/systemd/system systemd/step-ca.service"
            )
            (
              "the `postInstall` commands for service.step-ca.package "
              + "(likely pkgs.step-ca) have changed from when they were first overridden; "
              + "need to verify nothing else has moved or changed"
            )
            /*
            sh
            */
            ''
              install -Dm444 systemd/step-ca.service $out/lib/systemd/system/${lib.escapeShellArg config.systemd.services.mw-pki-rootCA.name}
            '';
        }
      ))
    ];

    services.step-ca = {
      enable = true;
      openFirewall = true;
      address = "127.0.0.1";
      port = let
        port = 52086;
      in
        lib.throwIf (
          port > 65535 - (config.services.mw-pki |> builtins.attrNames |> builtins.length)
        ) "the port used for the rootCA should have enough ports after it for all other pki services"
        port;
      # NOTE::IMPROVEMENT how do I keep up with the defaults of the generated
      # ca.json?
      # I could run `step ca init` and do checks on the output vs what I have
      # here. I could also apply transformations to get these values, and then
      # periodically (after each update to `step`) perform the transformation
      # using nix's wonderful build isolation chamber and compare the output to
      # what I have here, and note any changes as an error pointing to
      # configuration drift that should be addressed.
      settings = {
        db = {
          badgerFileLoadingMode = "";
          dataSource = "${STATE_DIRECTORY}/db";
          type = "badgerv2";
        };
        # The following are created by mw-pki-rootCA-make-certs-and-secrets.service, prior to mw-pki-rootCA.service running:
        # - root
        # - crt
        # - key
        # - ssh
        root = "${STATE_DIRECTORY}/certs/root_ca.crt";
        crt = "${STATE_DIRECTORY}/certs/intermediate_ca.crt";
        key = "${STATE_DIRECTORY}/secrets/intermediate_ca_key";
        ssh = {
          hostKey = "${STATE_DIRECTORY}/secrets/ssh_host_ca_key";
          userKey = "${STATE_DIRECTORY}/secrets/ssh_user_ca_key";
        };
        dnsNames = ["localhost"];
        federatedRoots = null;
        insecureAddress = "";
        logger = {
          format = "text";
        };
        tls = {
          cipherSuites = [
            "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
            "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
          ];
          maxVersion = 1.3;
          minVersion = 1.2;
          renegotiation = false;
        };
      };
    };

    systemd.services.mw-pki-rootCA-make-password = {
      name = "mw-pki-rootCA-make-password.service";
      description = "create credentials for ${config.systemd.services.mw-pki-rootCA-make-certs-and-secrets.name}";
      wantedBy = ["multi-user.target"];
      wants = ["first-boot-complete.target"];
      before = [
        "first-boot-complete.target"
        config.systemd.services.mw-pki-rootCA-make-certs-and-secrets.name
      ];
      unitConfig = {
        # NOTE::TESTING The vm isn't recreated each time, right now
        #ConditionFirstBoot = true;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        # used only for marking if the script has run already, so it doesn't
        # overwrite the password file
        StateDirectory = config.systemd.services.mw-pki-rootCA-make-password.name;
        ExecStart = let
          script_name = config.systemd.services.mw-pki-rootCA-make-password.name + ".sh";
          script = pkgs.writeShellApplication {
            name = script_name;
            runtimeInputs = [
              # for systemd-creds
              pkgs.systemd
            ];
            runtimeEnv =
              {
                CONFIG_DIR = configDir;
                inherit CREDENTIALS_DIRECTORY rootCAKeyPasswordCredentialName;
                inherit (cfg) rootCAKeyPasswordPath;
              }
              // (
                if cfg.insecure
                then {INSECURE = "true";}
                else {}
              );
            extraShellCheckFlags = [
              "--external-sources"
              shell-support.log-sh
            ];
            text =
              /*
              sh
              */
              ''
                set -eu

                MARKER="''${STATE_DIRECTORY:?"\$STATE_DIRECTORY not set"}/~${script_name}_was_run"
                if test -f "$MARKER"; then
                    info "marker file already exists: $MARKER"
                    info "exiting early"
                    exit 0
                fi

                . ${lib.escapeShellArg shell-support.log-sh}

                if test "$(id -u)" -ne 0; then
                    error "expected script to be run as root (uid 0), but got: $(id -un) (uid $(id -u))"
                fi

                # `umask` sets the file permissions I don't want on any newly created files and directories.
                # 377 disables write(2) and execute(1) for the user, and
                # read(4), write(2), and execute(1) for group and other.
                # This ensures that any newly created files can't be read by
                # anyone but root, since that's what this script will be running
                # as
                info 'setting umask to 377'
                umask 377

                if test -z "''${CREDENTIALS_DIRECTORY:-}"; then
                    error "expected \$CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                fi
                if EXPECTED_CREDENTIALS_DIRECTORY="$(systemd-path system-credential-store-encrypted)"; then
                    if test "$CREDENTIALS_DIRECTORY" != "$EXPECTED_CREDENTIALS_DIRECTORY"; then
                        error "The directory that systemd uses for encrypted credentials ($EXPECTED_CREDENTIALS_DIRECTORY) does not match the one set for this script ($CREDENTIALS_DIRECTORY).

                While this won't cause any problems, I decided a while ago that it is probably best for the two to match. Now is a time to decide between:

                  a) the value used in this script should be updated
                  b) the value used in this script shouldn't follow the systemd standard"
                    else
                        info "\$EXPECTED_CREDENTIALS_DIRECTORY matches \$CREDENTIALS_DIRECTORY"
                        set | grep -E '^EXPECTED_CREDENTIALS_DIRECTORY='
                        set | grep -E '^CREDENTIALS_DIRECTORY='
                    fi
                fi

                # read as: if removing the $CREDENTIALS_DIRECTORY from the
                # beginning of the $rootCAKeyPasswordPath results in the same
                # $rootCAKeyPasswordPath, then nothing was removed, meaning
                # $CREDENTIALS_DIRECTORY wasn't a prefix of
                # $rootCAKeyPasswordPath
                #
                # the comparison order is reversed from how it's stated above, so
                # that `shellcheck` sees that the existence of
                # $rootCAKeyPasswordPath is assured, before using it in parameter
                # expansion
                if test \
                    "''${rootCAKeyPasswordPath:?"\$rootCAKeyPasswordPath is not set"}" \
                    = \
                    "''${rootCAKeyPasswordPath#"$CREDENTIALS_DIRECTORY"}"
                then
                    error "the \$rootCAKeyPasswordPath ($rootCAKeyPasswordPath) is not in the \$CREDENTIALS_DIRECTORY ($CREDENTIALS_DIRECTORY)"
                fi

                info "making \$CREDENTIALS_DIRECTORY"
                mkdir -vp "''${CREDENTIALS_DIRECTORY}"

                if test -n "''${INSECURE:+"set"}"; then
                    PASSWORD='insecure'
                    info "using \"$PASSWORD\" as the root ca key password"
                    # the maximum age of this credential is supposed to be long
                    # enough that it'll eventually fail if accidentally used in
                    # production, but also long enough to use in a test
                    # NOTE::CONTINUE add logging saying where the key is being saved to
                    printf '%s' 'insecure' \
                        | systemd-creds encrypt \
                            --with-key=auto \
                            --not-after=+6h \
                            --name=''${rootCAKeyPasswordCredentialName:?"\$rootCAKeyPasswordCredentialName not set"} \
                            - \
                            "''${rootCAKeyPasswordPath}"
                else
                    error "secure storage of the password file for the root CA key has not been implemented yet; I intend to use sops-nix for that"
                fi
                chown --changes root:root -R "''${CREDENTIALS_DIRECTORY}"
                chmod --changes u=r,go= -R "''${CREDENTIALS_DIRECTORY}"

                info "creating a marker file so that this script isn't run a second time: $MARKER"
                touch "''${MARKER}"
                chown --changes "$(id -un):$(id -gn)" "''${MARKER}"
                chmod --changes a=r "''${MARKER}"
              '';
          };
        in
          lib.getExe script;
        enableStrictShellChecks = true;
      };
    };

    systemd.services.mw-pki-rootCA-make-certs-and-secrets = {
      name = "mw-pki-rootCA-make-certs-and-secrets.service";
      description = "like `step ca init`, but with ed25519 keys";
      wantedBy = ["multi-user.target"];
      wants = [
        "first-boot-complete.target"
        config.systemd.services.mw-pki-rootCA.name
      ];
      before = [
        "first-boot-complete.target"
        config.systemd.services.mw-pki-rootCA.name
      ];
      unitConfig = {
        # NOTE::TESTING the vm isn't recreated each time right now
        # NOTE::CONTINUE maybe this can be overridden at the site using the
        # module, and not here?
        #ConditionFirstBoot = true;
        JoinsNamespaceOf = [
          config.systemd.services.mw-pki-rootCA.name
        ];
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        User = config.systemd.services.mw-pki-rootCA.serviceConfig.User;
        Group = config.systemd.services.mw-pki-rootCA.serviceConfig.Group;
        DynamicUser = true;
        ExecStartPre = ["systemd-creds list"];
        inherit LoadCredentialEncrypted;
        StateDirectory = config.systemd.services.mw-pki-rootCA.serviceConfig.StateDirectory;
        # Is this necessary?
        #ReadWritePaths = ["%S/${config.systemd.services.step-ca-init.serviceConfig.StateDirectory}"];
        ExecStart =
          lib.getExe
          <| pkgs.writeShellApplication {
            name = "${config.systemd.services.mw-pki-rootCA-make-certs-and-secrets.name}.sh";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.sops
              pkgs.step-ca
              pkgs.step-cli
              pkgs.jq
              pkgs.openssh
            ];
            runtimeEnv =
              {
                CONFIG_DIR = configDir;
                EXPECTED_CREDENTIALS_DIRECTORY = CREDENTIALS_DIRECTORY;
                inherit (cfg) rootCAKeyPasswordPath;
                inherit rootCAKeyPasswordCredentialName;
              }
              // (
                if cfg.insecure
                then {INSECURE = "true";}
                else {}
              );
            extraShellCheckFlags = [
              "--external-sources"
              shell-support.log-sh
            ];
            text = let
              script_name = config.systemd.services.mw-pki-rootCA-make-certs-and-secrets.name;
            in
              /*
              sh
              */
              ''
                set -eu

                # instead of passing as a shell argument, pass as a path so that
                # `shellcheck` can follow it
                . ${lib.escapeShellArg shell-support.log-sh}

                STATE_DIRECTORY="''${STATE_DIRECTORY:?"\''$STATE_DIRECTORY not set"}"

                if EXPECTED_STATE_DIRECOTRY="$(systemd-path systemd-state-private)"; then
                    if test "$STATE_DIRECTORY" != "$EXPECTED_STATE_DIRECOTRY"; then
                        error "The directory that systemd uses for a units private state ($EXPECTED_CREDENTIALS_DIRECTORY) does not match the one set for this script ($CREDENTIALS_DIRECTORY).

                While this won't cause any problems, I decided a while ago that it is probably best for the two to match. Now is a time to decide between:

                  a) the value used in this script should be updated
                  b) the value used in this script shouldn't follow the systemd standard"
                    else
                        info "\$EXPECTED_STATE_DIRECOTRY matches \$STATE_DIRECTORY"
                        set | grep -E '^EXPECTED_STATE_DIRECOTRY='
                        set | grep -E '^STATE_DIRECTORY='
                    fi
                fi

                MARKER="''${STATE_DIRECTORY}/~${script_name}_was_run"
                if test -f "''${MARKER}"; then
                    info "marker file already exists: ''${MARKER}"
                    info "exiting early"
                    exit 0
                fi

                info "current user is: $(id)"
                info "\$STATE_DIRECTORY is: $STATE_DIRECTORY"
                set -x
                ls -alhR "''${STATE_DIRECTORY}/"
                ls -anhR "''${STATE_DIRECTORY}/"
                set +x

                info 'clearing previous setup'
                find -H "''${STATE_DIRECTORY}" \
                    -mindepth 1 \
                    -print \
                    '(' \
                        -delete \
                        -o \
                        -printf 'could not delete: %P\n' \
                    ')'

                CA_JSON="''${CONFIG_DIR:?"\$CONFIG_DIR not set"}/ca.json"
                info "collecting info from ca.json at: $CA_JSON"
                if ! test -f "''${CA_JSON}"; then
                    error "\$CA_JSON expected and not found at -> ''${CA_JSON}"
                fi
                if ! SSH_HOST_KEY="$(jq --raw-output --exit-status '.ssh.hostKey' "''${CA_JSON}")"; then
                    error "jq could not find host key path in ca.json -> ''${CA_JSON}"
                fi
                if ! SSH_USER_KEY="$(jq --raw-output --exit-status '.ssh.userKey' "''${CA_JSON}")"; then
                    error "jq could not find user key path in ca.json -> ''${CA_JSON}"
                fi
                if ! ROOT_CERT="$(jq --raw-output --exit-status '.root' "''${CA_JSON}")"; then
                    error "jq could not find root cert path in ca.json -> ''${CA_JSON}"
                fi
                if ! INTERMEDIATE_CERT="$(jq --raw-output --exit-status '.crt' "''${CA_JSON}")"; then
                    error "jq could not find intermediate cert path in ca.json -> ''${CA_JSON}"
                fi
                if ! INTERMEDIATE_KEY="$(jq --raw-output --exit-status '.key' "''${CA_JSON}")"; then
                    error "jq could not find intermediate key path in ca.json -> ''${CA_JSON}"
                fi

                # no -p because it should be an error if it already exists
                mkdir -v "''${STATE_DIRECTORY}/db"
                chmod --changes u=rwX,go= "''${STATE_DIRECTORY}"

                STEPPATH="''${STEPPATH:-"$STATE_DIRECTORY"}"
                export STEPPATH
                info "\$STEPPATH -> ''${STEPPATH}"

                SECRETS="''${STATE_DIRECTORY}/secrets"
                mkdir -v "''${SECRETS}"

                PASSWORD_FILE="''${CREDENTIALS_DIRECTORY:?"\$CREDENTIALS_DIRECTORY not set"}/''${rootCAKeyPasswordCredentialName:?"\$rootCAKeyPasswordCredentialName not set"}"
                if ! test -r "$PASSWORD_FILE"; then
                    error "cannot read \$PASSWORD_FILE at: $PASSWORD_FILE"
                fi
                info "\$PASSWORD_FILE -> ''${PASSWORD_FILE}"

                DATETIME="$(date --iso-8601=seconds)"
                info "\$DATETIME -> ''${DATETIME}"

                CERTS_DIR="''${STEPPATH}/certs"
                info "placing certificates and public keys in \$CERTS_DIR -> ''${CERTS_DIR}"
                mkdir -v "''${CERTS_DIR}"

                # This machine will be used to provide an intermediate CA key
                # to a connecting client. Because of that, if it were to
                # generate its own intermediate CA cert+key and sign the
                # client's CSR with that, there would be a chain of 2 CAs, and
                # smallstep's docs indicate that that isn't exactly the use
                # case this was designed for. Instead, the root CA cert+key can
                # be used as the intermediate one as well. That way, it's the
                # root that's signing the CA, not an ephemeral intermediate CA.
                #
                # Alternatively, the ephemeral intermediate CA could be
                # generated, and then one of the following could be done:
                # a) the actual intermediate CA could request an SSH key and
                #    log into to the root CA and copy the generated intermediate
                #    CA cert+key
                # b) the actual intermediate CA could use its cert to
                #    download the cert+key from the root CA, over a temporary
                #    HTTPS connection, using client authentication
                ssh-keygen \
                    -t ed25519 \
                    -C "intermediate CA host key @ ''${DATETIME}" \
                    -f "''${SSH_HOST_KEY}" \
                    -N "$(cat "''${PASSWORD_FILE}")"
                info 'moving .pub file for host key out of /secrets to /certs'
                mv -v "''${SSH_HOST_KEY}.pub" "''${CERTS_DIR}/"
                ssh-keygen \
                    -t ed25519 \
                    -C "intermediate CA user key ''${DATETIME}" \
                    -f "''${SSH_USER_KEY}" \
                    -N "$(cat "''${PASSWORD_FILE}")"
                info 'moving .pub file for user key to expected place'
                mv -v "''${SSH_USER_KEY}.pub" "''${CERTS_DIR}/"

                ROOT_KEY="''${SECRETS}/root_ca_key"
                info "creating a root ca certificate at -> ''${ROOT_CERT}"
                info "will be storing root key at -> ''${ROOT_KEY}"
                SUBJECT="''${INSECURE:+"test "}mw-pki root CA"
                if test -n "''${INSECURE-}"; then
                    VALID_FOR='24h'
                else
                    VALID_FOR="$((24 * 365))h"
                fi
                step certificate create \
                    "$SUBJECT" \
                    "''${ROOT_CERT}" \
                    "''${ROOT_KEY}" \
                    --kty=OKP \
                    --profile=root-ca \
                    --password-file="''${PASSWORD_FILE}" \
                    --not-before=-10m \
                    --not-after="$VALID_FOR"

                info "creating an intermediate ca certificate at -> ''${INTERMEDIATE_CERT}"
                info "will be storing intermediate key at -> ''${INTERMEDIATE_KEY}"
                step certificate create \
                    'test pki Intermediate CA' \
                    "''${INTERMEDIATE_CERT}" \
                    "''${INTERMEDIATE_KEY}" \
                    --kty=OKP \
                    --profile=intermediate-ca \
                    --password-file="''${PASSWORD_FILE}" \
                    --not-before=-10m \
                    --not-after="$VALID_FOR" \
                    --ca="''${ROOT_CERT}" \
                    --ca-key="''${ROOT_KEY}" \
                    --ca-password-file="''${PASSWORD_FILE}"

                info "creating a marker file so that this script isn't run a second time: $MARKER"
                touch "''${MARKER}"
                chown --changes "$(id -un):$(id -gn)" "''${MARKER}"
                chmod --changes a=r "''${MARKER}"
              '';
          };
      };
      enableStrictShellChecks = true;
      # I don't think this is necessary, since the script includes `runtimeInputs`
      #path = [
      #  pkgs.step-ca
      #  pkgs.step-cli
      #];
    };

    systemd.services.step-ca.enable = false;
    # I tried `config.systemd.services.step-ca // {my config;}` but got
    # infinite recursion errors, so copied from:
    # <https://github.com/NixOS/nixpkgs/blob/03d0d7bf47983664b75060c0edeb80fc04eebbdf/nixos/modules/services/security/step-ca.nix>
    systemd.services.mw-pki-rootCA = {
      name = "mw-pki-rootCA.service";
      wantedBy = ["multi-user.target"];
      restartTriggers = [configFile];
      unitConfig = {
        ConditionFileNotEmpty = ""; # override upstream
      };
      serviceConfig = {
        Type = "notify";
        User = "step-ca";
        Group = "step-ca";
        UMask = "0077";
        Environment = "HOME=%S/step-ca";
        WorkingDirectory = ""; # override upstream
        ReadWritePaths = [STATE_DIRECTORY]; # override upstream
        ReadOnlyPaths = [
          configDir
          #"%d"
        ];

        inherit LoadCredentialEncrypted;

        ExecStartPre = ["systemd-creds list"];
        ExecStart = [
          "" # override upstream
          "${lib.getExe config.services.step-ca.package} ${
            config.systemd.services.step-ca.restartTriggers |> builtins.head
          } --password-file=${lib.escapeShellArg cfg.rootCAKeyPasswordPath}"
        ];

        # ProtectProc = "invisible"; # not supported by upstream yet
        # ProcSubset = "pid"; # not supported by upstream yet
        # PrivateUsers = true; # doesn't work with privileged ports therefore not supported by upstream

        DynamicUser = true;
        StateDirectory = "step-ca";
      };
    };
  };
}
