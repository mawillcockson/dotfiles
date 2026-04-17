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
  cfg = config.services.mw-pki.intermediateCA;

  base64-root-ca-crt =
    pkgs.runCommandLocal "base64-root-ca-crt"
    {
      inherit (cfg) rootCACertPath;
      nativeBuildInputs = [pkgs.coreutils];
    }
    ''
      set -eu
      base64 "$rootCACertPath" | tr -d '\n' > "$out"
    '';

  # NOTE::BUG causes an infinite recursion
  #configDir = config.systemd.services.step-ca.restartTriggers |> builtins.head |> builtins.dirOf;
  configDir = "/etc/smallstep";
  # NOTE::DONE there's a note in systemd.exec(5) under LoadCredential
  # about using `systemd-path` with an invocation like `systemd-run --collect
  # --wait --pty -- systemd-path system-credential-store-encrypted` to get the specific path to the
  # credentials directory, but it didn't work for me
  # <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#LoadCredential=ID:PATH>
  # it looks like it IS just missing for me:
  #
  # debian 13 has `systemd-path --version` 257.9-1~deb13u1
  # nixos-unstable has version 259
  #
  # It would be cool if this value maybe were derived from invoking
  # `systemd-path system-credential-store-encrypted`, but that would be an
  # import-from-derivation, so instead it can be validated at runtime against
  # the output of that command.
  # This is done by `mw-pki-rootCA-make-password.service`
  EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY = "/etc/credstore.encrypted";
  EXPECTED_CREDENTIALS_DIRECTORY = "/etc/credstore";
  # similar to the note for CREDENTIALS_DIRECTORY in constants.nix, this is
  # checked in `mw-pki-rootCA-make-certs-and-secrets.service`
  EXPECTED_STATE_DIRECTORY = "/var/lib/${config.systemd.services.step-ca.name}";
in {
  options.services.mw-pki.intermediateCA = {
    enable = lib.mkEnableOption "intermediateCA";
    beRootCA = lib.mkEnableOption "rootCA";
    rootCAKeyPasswordPath = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      description = ''
        where the password for the root ca key is stored
        this must be outside the nix store
      '';
      example = lib.literalExpression ''"/etc/credstore.encrypted/mw-pki-root-key-password"'';
    };
    rootCAKeyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.externalPath;
      default = null;
      description = ''
        where the root ca key is stored
        this must be outside the nix store
      '';
      example = lib.literalExpression ''"/etc/credstore.encrypted/mw-pki-root-key"'';
    };
    rootCACertPath = lib.mkOption {
      type = lib.types.externalPath;
      description = ''
        where the root ca certificate is stored
        this must be outside the nix store
      '';
      example = lib.literalExpression ''"/etc/smallstep/certs/root_ca.crt"'';
    };
    intermediateCAKeyPasswordPath = lib.mkOption {
      type = lib.types.externalPath;
      default = config.services.step-ca.settings.key + "_password";
      description = ''
        where the intermediate ca key password is stored
        this must be outside the nix store
        by default, it will be the same as the intermediate ca key, with "_password" appended
      '';
      example = lib.literalExpression ''"/etc/credstore/mw-pki-intermediate-key_password"'';
    };
    sshHostKeyPath = lib.mkOption {
      type = lib.types.externalPath;
      description = "where this module should place the ssh host key it will receive from the root ca";
      example = lib.literalExpression ''"/etc/credstore.encrypted/sshHostKey"'';
    };
    sshUserCAKey = lib.mkOption {
      type = lib.types.externalPath;
      description = "the ssh key used as the user ca";
      example = lib.literalExpression ''"/etc/credstore.encrypted/ssh_user_ca_key"'';
    };
    sshHostCAKey = lib.mkOption {
      type = lib.types.externalPath;
      description = "the ssh key used as the host ca";
      example = lib.literalExpression ''"/etc/credstore.encrypted/ssh_host_ca_key"'';
    };
    root-ca-url = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "URL the root ca is reachable at";
      example = lib.literalExpression ''"https://ca.example.com:8229"'';
    };
    intermediate-ca-fqdn = lib.mkOption {
      type = lib.type.nonEmptyStr;
      description = ''
        The Fully Qualified Domain Name of the intermediate ca
        will be used to verify it over ACME
      '';
      example = lib.literalExpression ''"ca.example.com"'';
    };
    sshHostAllowedDomainNames = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.nonEmptyStr);
      default = null;
      description = "dns names to allow in ssh host certificates";
      example = lib.literalExpression ''["example.com"]'';
    };
    sshUserAllowedPrincipals = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.nonEmptyStr);
      default = null;
      description = "principals to allow in ssh user certificates";
      example = lib.literalExpression ''["root"]'';
    };
    x509AllowedDomainNames = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.nonEmptyStr);
      default = null;
      description = "dns names to allow in x509 certificates";
      example = lib.literalExpression ''["example.com"]'';
    };
    stepNotBefore = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "-10m";
      description = ''
        the date after which all step certificates are valid
        this is given to the --not-before option passed to step-cli invocations'';
      example = lib.literalExpression ''"now"'';
    };
    stepNotAfter = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "${24 * 365}h";
      description = ''
        validity interval to use for certificates generated by step
        this is given to the --not-after option passed to step-cli invocations
      '';
      example = lib.literalExpression ''"1y"'';
    };
    contactEmail = lib.mkOption {
      type = lib.types.nonEmptyStr;
      description = "email to use when usinc ACME with the step ca";
      example = lib.literalExpression ''"test@example.invalid"'';
    };
  };

  config = lib.mkIf (cfg.enable) {
    services.step-ca = {
      enable = true;
      openFirewall = true;
      address = "127.0.0.1";
      port = 52086;
      # NOTE::IMPROVEMENT how do I keep up with the defaults of the generated
      # ca.json?
      # I could run `step ca init` and do checks on the output vs what I have
      # here. I could also apply transformations to get these values, and then
      # periodically (after each update to `step`) perform the transformation
      # using nix's wonderful build isolation chamber and compare the output to
      # what I have here, and note any changes as an error pointing to
      # configuration drift that should be addressed.
      settings = {
        root = cfg.rootCACertPath; # "${EXPECTED_STATE_DIRECTORY}/certs/root_ca.crt";
        # the rest are retrieved from the rootCA, and may not yet exist
        crt = "${EXPECTED_STATE_DIRECTORY}/certs/intermediate_ca.crt";
        key = "${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY}/intermediate_ca_key";
        ssh = {
          hostKey = "${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY}/ssh_host_ca_key";
          userKey = "${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY}/ssh_user_ca_key";
        };

        logger = {
          format = "text";
        };

        dnsNames = ["localhost"];
        federatedRoots = null;
        insecureAddress = "";

        authority =
          {
            provisioners = [
              {
                type = "ACME";
                name = "acme";
                # currently, my version of step-ca is v0.29.0
                # That version uses smallstep/crypto v0.74.0:
                # https://github.com/smallstep/certificates/blob/v0.29.0/go.mod#L40
                # These are the default templates for that version:
                # https://github.com/smallstep/crypto/blob/v0.74.0/x509util/templates.go#L140-L151
                options = {
                  x509.template =
                    if cfg.beRootCA
                    then
                      /*
                      json
                      */
                      ''
                        {{ if .Subject | eq "${cfg.intermediate-ca-fqdn}" }}
                        {
                          "subject": {{ toJson .Subject }},
                          "keyUsage": ["certSign", "crlSign", "digitalSignature"],
                          "basicConstraints": {
                            "isCA": true,
                            "maxPathLen": 0
                          }
                        }
                        {{ else }}
                        {{ fail "this ca is only used for signing certificates for the intermediate ca ${cfg.intermediate-ca-fqdn}" }}
                        {{ end }}

                        {{- if not "leaf" -}}
                        {
                          "subject": {{ toJson .Subject }},
                          "sans": {{ toJson .SANs }},
                        {{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
                          "keyUsage": ["keyEncipherment", "digitalSignature"],
                        {{- else }}
                          "keyUsage": ["digitalSignature"],
                        {{- end }}
                          "extKeyUsage": ["serverAuth", "clientAuth"]
                        }
                        {{- end -}}
                        {{- if not "intermediate" -}}
                        {
                          "subject": {{ toJson .Subject }},
                          "keyUsage": ["certSign", "crlSign"],
                          "basicConstraints": {
                            "isCA": true,
                            "maxPathLen": 0
                          }
                        }
                        {{- end -}}
                        {{- if not "root" -}}
                        {
                          "subject": {{ toJson .Subject }},
                          "issuer": {{ toJson .Subject }},
                          "keyUsage": ["certSign", "crlSign"],
                          "basicConstraints": {
                            "isCA": true,
                            "maxPathLen": 1
                          }
                        }
                        {{- end -}}
                      ''
                    else
                      /*
                      json
                      */
                      ''
                        {
                          "subject": {{ toJson .Subject }},
                          "sans": {{ toJson .SANs }},
                        {{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
                          {{ fail "I don't like RSA keys" }}
                          "keyUsage": ["keyEncipherment", "digitalSignature"],
                        {{- else }}
                          "keyUsage": ["digitalSignature"],
                        {{- end }}
                          "extKeyUsage": ["serverAuth", "clientAuth"]
                        }
                      '';
                };
              }
              {
                type = "SSHPOP";
                name = "sshpop";
                claims = {
                  enableSSHCA = true;
                };
              }
              {
                type = "X5C";
                name = "x5c";
                roots = base64-root-ca-crt;
                claims = {
                  allowRenewalAfterExpiry = false;
                  disableRenewal = false;
                  disableSmallstepExtensions = false;
                  enableSSHCA = true;
                };
                options.x509.template =
                  /*
                  json
                  */
                  ''
                    {
                      "subject": {{ toJson .Subject }},
                      "sans": {{ toJson .SANs }},
                    {{- if typeIs "*rsa.PublicKey" .Insecure.CR.PublicKey }}
                      "keyUsage": ["keyEncipherment", "digitalSignature"],
                    {{- else }}
                      "keyUsage": ["digitalSignature"],
                    {{- end }}
                      "uris": ["https://worked.example"],
                      "extKeyUsage": ["serverAuth", "clientAuth"]
                    }
                  '';
                # options.ssh.template = /* json */ '''';
              }
            ];
          }
          // (
            if isNull cfg.x509AllowedDomainNames
            then {}
            else {
              x509.allow.dns = cfg.x509AllowedDomainNames;
            }
          )
          // (
            if isNull cfg.sshHostAllowedDomainNames
            then {}
            else {
              ssh.host.allow.dns = cfg.sshHostAllowedDomainNames;
            }
          )
          // (
            if isNull cfg.sshUserAllowedPrincipals
            then {}
            else {
              ssh.user.allow.principal = cfg.sshUserAllowedPrincipals;
            }
          );

        db = {
          badgerFileLoadingMode = "";
          dataSource = "${EXPECTED_STATE_DIRECTORY}/db";
          type = "badgerv2";
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

        # step-ca does not seem to mind having this extra key here
        templates.custom =
          if cfg.beRootCA
          then {
            root =
              /*
              json
              */
              ''
                {
                  "subject": {{ toJson .Subject }},
                  "issuer": {{ toJson .Subject }},
                  "keyUsage": ["certSign", "crlSign"],
                  "basicConstraints": {
                    "isCA": true,
                    "maxPathLen": 2
                  }
                }
              '';
            intermediate =
              /*
              json
              */
              ''
                {
                  "subject": {{ toJson .Subject }},
                  "keyUsage": ["certSign", "crlSign"],
                  "basicConstraints": {
                    "isCA": true,
                    "maxPathLen": 1
                  }
                }
              '';
          }
          else {};
      };
    };

    systemd.services.mw-pki-init = let
      step-ca.service = config.systemd.services.step-ca.name;
      step-ca-serviceConfig = config.systemd.services.step-ca.serviceConfig;
    in {
      name = "mw-pki-init.service";
      description = ''
        checks that all the paths specified conform as best as possible to `systemd-path`
        creates the intermediate ca key and cert, and submits a CSR
        makes ssh keys
        encrypts credentials with systemd-creds
      '';
      wantedBy = ["multi-user.target"];
      wants = [
        step-ca.service
      ];
      before = [
        step-ca.service
      ];
      unitConfig = {
        JoinsNamespaceOf = [
          step-ca.service
        ];
      };
      enableStrictShellChecks = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        # this needs to run as root, I think
        #User = step-ca-serviceConfig.User;
        #Group = step-ca-serviceConfig.Group;
        #DynamicUser = true;

        # don't need $CREDENTIALS_DIRECTORY, don't need to check it
        ## need a credential, in order for $CREDENTIALS_DIRECTORY to be set in
        ## the script's environment
        #SetCredential = "example-credential-name:example-credential-value";

        StateDirectory = step-ca-serviceConfig.StateDirectory;
        Environment = ["STEPPATH=%S"];
        # Is this necessary?
        #ReadWritePaths = ["%S/${step-ca-serviceConfig.StateDirectory}"];
        ExecStart =
          lib.getExe
          <| pkgs.writeShellApplication (
            let
              script_name = "${config.systemd.services.mw-pki-check-paths.name}.sh";
            in {
              name = script_name;
              runtimeInputs = [
                # I'm not sure I need to specify systemd as a dependency: if
                # it's not there, this script should fail, because I should be
                # using systemd on the system
                #pkgs.systemd
                pkgs.coreutils
                pkgs.step-ca
                pkgs.step-cli
                pkgs.jq
              ];
              runtimeEnv =
                {
                  CA_CONFIG = "${configDir}/ca.json";
                  STEP_VALIDITY_NOT_BEFORE = cfg.stepNotBefore;
                  STEP_VALIDITY_NOT_AFTER = cfg.stepNotAfter;
                  SCRIPT_NAME = script_name;
                  inherit
                    EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY
                    EXPECTED_CREDENTIALS_DIRECTORY
                    EXPECTED_STATE_DIRECTORY
                    ;
                  ROOT_CA_URL = cfg.root-ca-url;
                  INTERMEDIATE_CA_FQDN = cfg.intermediate-ca-fqdn;
                  inherit (cfg) rootCACertPath;

                  inherit (cfg) intermediateCAKeyPasswordPath;
                  intermediateCAKeyPasswordCredentialName = baseNameOf cfg.intermediateCAKeyPasswordPath;
                  intermediateCAKeyPath = config.services.step-ca.settings.key;
                  intermediateCAKeyCredentialName = baseNameOf config.services.step-ca.settings.key;

                  sshHostCAKeyPath = config.services.step-ca.settings.ssh.hostKey;
                  sshHostCAKeyCredentialName = baseNameOf config.services.step-ca.settings.ssh.hostKey;
                  sshUserCAKeyPath = config.services.step-ca.settings.ssh.userKey;
                  sshUserCAKeyCredentialName = baseNameOf config.services.step-ca.settings.ssh.userKey;
                  inherit (cfg) sshHostKeyPath;
                  sshHostKeyCredentialName = baseNameOf cfg.sshHostKeyPath;
                }
                // (
                  if cfg.beRootCA
                  then {
                    inherit (cfg) beRootCA;
                    inherit (cfg) rootCAKeyPasswordPath;
                    # not needed, because the credential isn't provided through
                    # systemd's Load/SetCredential, so the credential name is
                    # never needed
                    #rootCAKeyPasswordCredentialName = baseNameOf cfg.rootCAKeyPasswordPath;
                    inherit (cfg) rootCAKeyPath;
                    #rootCAKeyCredentialName = baseNameOf cfg.rootCAKeyPath;
                  }
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
                  # instead of passing as a shell argument, pass as a path so that
                  # `shellcheck` can follow it
                  . ${lib.escapeShellArg shell-support.log-sh}
                  markError() {
                      log ERROR "$*"
                      ENCOUNTERED_ERROR=true
                  }
                  reportMarkedError() {
                      if test -z "''${ENCOUNTERED_ERROR:+"set"}"; then
                          warn "no error encountered"
                      else
                          unset -v ENCOUNTERED_ERROR || log ERROR "unable to unset \$ENCOUNTERED_ERROR"
                          error "$*"
                      fi
                  }

                  # `umask` sets the file permissions I don't want on any newly created files and directories.
                  # 377 disables write(2) and execute(1) for the user, and
                  # read(4), write(2), and execute(1) for group and other.
                  # This ensures that any newly created files can't be read by
                  # anyone but root, since that's what this script will be running
                  # as
                  info 'setting umask to 377'
                  umask 377

                  if ! TMPDIR="''${TMPDIR:-"$(mktemp -td)"}"; then
                      error "cannot define \$TMPDIR; issue with mktemp"
                  elif ! mkdir -vp "$TMPDIR"; then
                      error "cannot create \$TMPDIR; issue with mkdir"
                  elif ! touch "$TMPDIR/test.txt"; then
                      error "cannot create a file test.txt in \$TMPDIR=$TMPDIR; issue with touch"
                  else
                      info "using \$TMPDIR=$TMPDIR"
                  fi

                  if test -z "''${CA_CONFIG:+"set"}"; then
                      markError "\$CA_CONFIG not set"
                  elif ! test -r "$CA_CONFIG"; then
                      markError "cannot read the ca configuration file at \$CA_CONFIG=$CA_CONFIG"
                  elif ! jq -ne -- . "$CA_CONFIG" >/dev/null; then
                      markError "jq could not read the ca configuration file at \$CA_CONFIG=$CA_CONFIG"
                  else
                      info "using the ca configuration file at \$CA_CONFIG=$CA_CONFIG"
                  fi

                  if ! DATETIME="$(date --iso-8601=seconds)"; then
                      markError "could not set \$DATETIME; problem with 'date'"
                  else
                      info "\$DATETIME -> ''${DATETIME}"
                  fi

                  if test -z "''${ROOT_CA_URL:+"set"}"; then
                      markError "\$ROOT_CA_URL not set"
                  else
                      info "using this as the root ca url: ''${ROOT_CA_URL:?"\$ROOT_CA_URL not set"}"
                  fi

                  if test -z "''${INTERMEDIATE_CA_FQDN:+"set"}"; then
                      markError "\$INTERMEDIATE_CA_FQDN not set"
                  else
                      info "using this as the intermediate ca's fully qualified domain name, and certificate Subject: ''${INTERMEDIATE_CA_FQDN:?"\$INTERMEDIATE_CA_FQDN not set"}"
                  fi

                  if test -z "''${STEP_VALIDITY_NOT_BEFORE:+"set"}"; then
                      markError "\$STEP_VALIDITY_NOT_BEFORE not set"
                  else
                      info "all step certificates won't be valid before: \$STEP_VALIDITY_NOT_BEFORE=$STEP_VALIDITY_NOT_BEFORE"
                  fi
                  if test -z "''${STEP_VALIDITY_NOT_AFTER:+"set"}"; then
                      markError "\$STEP_VALIDITY_NOT_AFTER not set"
                  else
                      info "all step certificates won't be valid after: \$STEP_VALIDITY_NOT_AFTER=$STEP_VALIDITY_NOT_AFTER"
                  fi

                  if test -z "''${EXPECTED_CREDENTIALS_DIRECTORY:+"set"}"; then
                      markError "expected \$EXPECTED_CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                  else
                      info "\$EXPECTED_CREDENTIALS_DIRECTORY=$EXPECTED_CREDENTIALS_DIRECTORY"
                  fi
                  if ! SYSTEMD_CREDENTIALS_DIRECTORY="$(systemd-path system-credential-store)"; then
                      markError 'systemd-path returned an error for `system-credetial-store`'
                  else
                      if \
                          test "''${EXPECTED_CREDENTIALS_DIRECTORY-}" \
                          != \
                          "''${SYSTEMD_CREDENTIALS_DIRECTORY:?"\$SYSTEMD_CREDENTIALS_DIRECTORY is not set or empty"}"
                      then
                          markError "The directory that systemd uses for credentials ($SYSTEMD_CREDENTIALS_DIRECTORY) does not match the one that the mw-pki configuration expects to be used (''${EXPECTED_CREDENTIALS_DIRECTORY-}).

                  While this won't cause any problems, I decided a while ago that it is probably best for the two to match. Now is a time to decide between:

                    a) the value used in this script should be updated
                    b) the value used in this script shouldn't follow the systemd standard
                    c) this shouldn't be an error"
                      else
                          info "\$SYSTEMD_CREDENTIALS_DIRECTORY matches \$EXPECTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^SYSTEMD_CREDENTIALS_DIRECTORY=' || echo 'SYSTEMD_CREDENTIALS_DIRECTORY='
                      set | grep -E '^EXPECTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_CREDENTIALS_DIRECTORY='
                  fi

                  if test -z "''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY:+"set"}"; then
                      markError "expected \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                  else
                      info "\$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                  fi
                  if SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY="$(systemd-path system-credential-store-encrypted)"; then
                      markError 'systemd-path returned an error for `system-credential-store-encrypted`'
                  else
                      if \
                          test \
                          "''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY-}" \
                          != \
                          "''${SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY:?"\$SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY is not set or empty"}"
                      then
                          markError "The directory that systemd uses for encrypted credentials ($SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY) does not match the one that the mw-pki configuration expects to be used (''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY-}).

                  While this won't cause any problems, I decided a while ago that it is probably best for the two to match. Now is a time to decide between:

                    a) the value used in this script should be updated
                    b) the value used in this script shouldn't follow the systemd standard
                    c) this shouldn't be an error"
                      else
                          info "\$SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY matches \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                  fi

                  if test -z "''${STATE_DIRECTORY:+"set"}"; then
                      markError "expected \$STATE_DIRECTORY to be set in the environment that this script is run in"
                  fi
                  if test -z "''${EXPECTED_STATE_DIRECTORY:+"set"}"; then
                      markError "expected \$EXPECTED_STATE_DIRECTORY to be set in the environment that this script is run in"
                  fi

                  if SYSTEMD_STATE_DIRECTORY="$(systemd-path system-state-private)"; then
                      if test "$SYSTEMD_STATE_DIRECTORY" != "''${EXPECTED_STATE_DIRECTORY-}"; then
                          markError "The directory that systemd uses for a unit's private state (\$SYSTEMD_STATE_DIRECTORY) does not match the one set for this script (\$EXPECTED_STATE_DIRECTORY).

                  While this won't cause any problems, I decided a while ago that it is probably best for the two to match. Now is a time to decide between:

                    a) the value used in this script should be updated
                    b) the value used in this script shouldn't follow the systemd standard"
                      else
                          info "\$EXPECTED_STATE_DIRECTORY matches \$SYSTEMD_STATE_DIRECTORY"
                      fi
                      set | grep -E '^STATE_DIRECTORY=' || echo 'STATE_DIRECTORY='
                      set | grep -E '^EXPECTED_STATE_DIRECTORY=' || echo 'EXPECTED_STATE_DIRECTORY='
                      set | grep -E '^SYSTEMD_STATE_DIRECTORY=' || echo 'SYSTEMD_STATE_DIRECTORY='
                  fi

                  if test -z "''${STEPPATH:+"set"}"; then
                      markError "\$STEPPATH not set"
                  elif test \
                      "''${STEPPATH:?"\$STEPPATH not set"}" \
                      != \
                      "''${STEPPATH#"$STATE_DIRECTORY"}"
                  then
                      markError "\$STEPPATH not in \$STATE_DIRECTORY"
                  else
                      info "using this as \$STEPPATH=$STEPPATH"
                  fi
                  set | grep -E '^STATE_DIRECTORY=' || echo 'STATE_DIRECTORY='
                  set | grep -E '^STEPPATH=' || echo 'STEPPATH='

                  fi

                  if test -n "''${beRootCA:+"set"}"; then
                      if test -z "''${rootCAKeyPasswordPath:+"set"}"; then
                          markError "\$rootCAKeyPasswordPath not set"
                      else
                          info "root ca key password path is: ''${rootCAKeyPasswordPath:?"impossible"}"
                      fi
                      set | grep -E '^rootCAKeyPasswordPath=' || echo 'rootCAKeyPasswordPath='
                      # not needed, because the credential isn't provided through
                      # systemd's Load/SetCredential, so the credential name is
                      # never needed
                      #info "\$rootCAKeyPasswordCredentialName=''${rootCAKeyPasswordCredentialName:?"\$rootCAKeyPasswordCredentialName not set"}"

                      if test -z "''${rootCAKeyPath:+"set"}"; then
                          markError "\$rootCAKeyPath not set"
                      else
                          info "root ca key path is: ''${rootCAKeyPath:?"impossible"}"
                      fi
                      set | grep -E '^rootCAKeyPath=' || echo 'rootCAKeyPath='
                      #info "\$rootCAKeyCredentialName=''${rootCAKeyCredentialName:?"\$rootCAKeyCredentialName not set"}"
                  fi
                  if test -z "''${rootCACertPath:+"set"}"; then
                      markError "\$rootCACertPath not set"
                  else
                      if test "''${rootCACertPath}" = "''${rootCACertPath#"$STATE_DIRECTORY"}"; then
                          # prefix not removed
                          markError "\$rootCACertPath not in \$STATE_DIRECTORY"
                      else
                          # prefix removed
                          info "\$rootCACertPath is in \$STATE_DIRECTORY"
                      fi
                  fi
                  set | grep -E '^STATE_DIRECTORY=' || echo 'STATE_DIRECTORY='
                  set | grep -E '^rootCACertPath=' || echo 'rootCACertPath='

                  # these are always tested, because they're always used
                  if test -z "''${intermediateCAKeyPasswordPath:+"set"}"; then
                      markError "\$intermediateCAKeyPasswordPath not set"
                  else
                      # read as: if removing the $CREDENTIALS_DIRECTORY from
                      # the beginning of the $intermediateCAKeyPasswordPath
                      # results in the same $intermediateCAKeyPasswordPath,
                      # then nothing was removed, meaning
                      # $CREDENTIALS_DIRECTORY wasn't a prefix of
                      # $intermediateCAKeyPasswordPath
                      #
                      # the comparison order is reversed from how it's stated
                      # above, so that `shellcheck` sees that the existence of
                      # $intermediateCAKeyPasswordPath is assured, before using
                      # it in parameter expansion
                      if test \
                          "''${intermediateCAKeyPasswordPath:?"\$intermediateCAKeyPasswordPath is not set"}" \
                          = \
                          "''${intermediateCAKeyPasswordPath#"$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"}"
                      then
                          markError "the \$intermediateCAKeyPasswordPath is not in the \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      else
                          info "the \$intermediateCAKeyPasswordPath is in \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^intermediateCAKeyPasswordPath=' || echo 'intermediateCAKeyPasswordPath='
                  fi
                  if test -z "''${intermediateCAKeyPasswordCredentialName:+"set"}"; then
                      markError "\$intermediateCAKeyPasswordCredentialName is not set"
                  else
                      if ! INTERMEDIATE_CA_KEY_PASSWORD_CREDENTIAL_NAME="$(basename "$intermediateCAKeyPasswordPath")"; then
                          markError "problem using 'basename' on \$intermediateCAKeyPasswordPath=$intermediateCAKeyPasswordPath"
                      elif test \
                          "$intermediateCAKeyPasswordCredentialName" \
                          = \
                          "$INTERMEDIATE_CA_KEY_PASSWORD_CREDENTIAL_NAME";
                      then
                          info "\$intermediateCAKeyPasswordCredentialName matches what GNU coreutils 'basename' produced"
                      else
                          warn "'basename' on \$intermediateCAKeyPasswordPath produced different result"
                      fi
                      set | grep -E '^INTERMEDIATE_CA_KEY_PASSWORD_CREDENTIAL_NAME=' \
                          || warn "could not show \$INTERMEDIATE_CA_KEY_PASSWORD_CREDENTIAL_NAME"
                      set | grep -E '^intermediateCAKeyPasswordPath=' || warn "could not show \$intermediateCAKeyPasswordPath"
                  fi

                  if test -z "''${intermediateCAKeyPath:+"set"}"; then
                      markError "\$intermediateCAKeyPath not set"
                  else
                      if test \
                          "''${intermediateCAKeyPath:?"\$intermediateCAKeyPath is not set"}" \
                          = \
                          "''${intermediateCAKeyPath#"$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"}"
                      then
                          markError "the \$intermediateCAKeyPath is not in the \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      else
                          info "the \$intermediateCAKeyPath is in \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^intermediateCAKeyPath=' || echo 'intermediateCAKeyPath='
                  fi
                  if test -z "''${intermediateCAKeyCredentialName:+"set"}"; then
                      markError "\$intermediateCAKeyCredentialName not set"
                  else
                      if ! INTERMEDIATE_CA_KEY_CREDENTIAL_NAME="$(basename "$intermediateCAKeyPath")"; then
                          markError "problem using 'basename' on \$intermediateCAKeyPath=$intermediateCAKeyPath"
                      elif test \
                          "$intermediateCAKeyCredentialName" \
                          = \
                          "$INTERMEDIATE_CA_KEY_CREDENTIAL_NAME";
                      then
                          info "\$intermediateCAKeyCredentialName matches what GNU coreutils 'basename' produced"
                      else
                          warn "'basename' on \$intermediateCAKeyCredentialName produced different result"
                      fi
                      set | grep -E '^INTERMEDIATE_CA_KEY_CREDENTIAL_NAME=' || warn "could not show \$INTERMEDIATE_CA_KEY_CREDENTIAL_NAME"
                      set | grep -E '^intermediateCAKeyCredentialName=' || warn "could not show \$intermediateCAKeyCredentialName"
                  fi

                  if test -z "''${intermediateCACertPath:+"set"}"; then
                      markError "\$intermediateCACertPath not set"
                  else
                      if test \
                          "''${intermediateCACertPath}" \
                          = \
                          "''${intermediateCACertPath#"$STATE_DIRECTORY"}"
                      then
                          markError "the \$intermediateCACertPath is not in the \$STATE_DIRECTORY"
                      else
                          info "the \$intermediateCACertPath is in \$STATE_DIRECTORY"
                      fi
                      set | grep -E '^STATE_DIRECTORY=' || echo 'STATE_DIRECTORY='
                      set | grep -E '^intermediateCAKeyPath=' || echo 'intermediateCAKeyPath='
                  fi

                  if test -z "''${sshHostCAKeyPath:+"set"}"; then
                      markError "\$sshHostCAKeyPath not set"
                  else
                      if test \
                          "''${sshHostCAKeyPath}" \
                          = \
                          "''${sshHostCAKeyPath#"$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"}"
                      then
                          markError "the \$sshHostCAKeyPath is not in the \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      else
                          info "the \$sshHostCAKeyPath is in \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^sshHostCAKeyPath=' || echo 'sshHostCAKeyPath='
                  fi
                  if test -z "''${sshHostCAKeyCredentialName:+"set"}"; then
                      markError "\$sshHostCAKeyCredentialName not set"
                  else
                      if ! SSH_HOST_CA_KEY_CREDENTIAL_NAME="$(basename "$sshHostCAKeyPath")"; then
                          markError "problem using 'basename' on \$sshHostCAKeyPath=$sshHostCAKeyPath"
                      elif test \
                          "$sshHostCAKeyCredentialName" \
                          = \
                          "$SSH_HOST_CA_KEY_CREDENTIAL_NAME";
                      then
                          info "\$sshHostCAKeyCredentialName matches what GNU coreutils 'basename' produced"
                      else
                          warn "'basename' on \$sshHostCAKeyCredentialName produced different result"
                      fi
                      set | grep -E '^SSH_HOST_CA_KEY_CREDENTIAL_NAME=' || warn "could not show \$SSH_HOST_CA_KEY_CREDENTIAL_NAME"
                      set | grep -E '^sshHostCAKeyCredentialName=' || warn "could not show \$sshHostCAKeyCredentialName"
                  fi

                  if test -z "''${sshUserCAKeyPath:+"set"}"; then
                      markError "\$sshUserCAKeyPath not set"
                  else
                      if test \
                          "''${sshUserCAKeyPath}" \
                          = \
                          "''${sshUserCAKeyPath#"$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"}"
                      then
                          markError "the \$sshUserCAKeyPath is not in the \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      else
                          info "the \$sshUserCAKeyPath is in \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^sshUserCAKeyPath=' || echo 'sshUserCAKeyPath='
                  fi
                  if test -z "''${sshUserCAKeyCredentialName:+"set"}"; then
                      markError "\$sshUserCAKeyCredentialName not set"
                  else
                      if ! SSH_USER_CA_KEY_CREDENTIAL_NAME="$(basename "$sshUserCAKeyPath")"; then
                          markError "problem using 'basename' on \$sshUserCAKeyPath=$sshUserCAKeyPath"
                      elif test \
                          "$sshUserCAKeyCredentialName" \
                          = \
                          "$SSH_USER_CA_KEY_CREDENTIAL_NAME";
                      then
                          info "\$sshUserCAKeyCredentialName matches what GNU coreutils 'basename' produced"
                      else
                          warn "'basename' on \$sshUserCAKeyCredentialName produced different result"
                      fi
                      set | grep -E '^SSH_USER_CA_KEY_CREDENTIAL_NAME=' || warn "could not show \$SSH_USER_CA_KEY_CREDENTIAL_NAME"
                      set | grep -E '^sshUserCAKeyCredentialName=' || warn "could not show \$sshUserCAKeyCredentialName"
                  fi

                  if test -z "''${sshHostKeyPath:+"set"}"; then
                      markError "\$sshHostKeyPath not set"
                  else
                      if test \
                          "''${sshHostKeyPath}" \
                          = \
                          "''${sshHostKeyPath#"$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"}"
                      then
                          markError "the \$sshHostKeyPath is not in the \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      else
                          info "the \$sshHostKeyPath is in \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY"
                      fi
                      set | grep -E '^EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^sshHostKeyPath=' || echo 'sshHostKeyPath='
                  fi
                  if test -z "''${sshHostKeyCredentialName:+"set"}"; then
                      markError "\$sshHostKeyCredentialName not set"
                  else
                      if ! SSH_HOST_KEY_CREDENTIAL_NAME="$(basename "$sshHostKeyPath")"; then
                          markError "problem using 'basename' on \$sshHostKeyPath=$sshHostKeyPath"
                      elif test \
                          "$sshHostKeyCredentialName" \
                          = \
                          "$SSH_HOST_KEY_CREDENTIAL_NAME";
                      then
                          info "\$sshHostKeyCredentialName matches what GNU coreutils 'basename' produced"
                      else
                          warn "'basename' on \$sshHostKeyCredentialName produced different result"
                      fi
                      set | grep -E '^SSH_HOST_KEY_CREDENTIAL_NAME=' || warn "could not show \$SSH_HOST_KEY_CREDENTIAL_NAME"
                      set | grep -E '^sshHostKeyCredentialName=' || warn "could not show \$sshHostKeyCredentialName"
                  fi

                  if test -n "''${beRootCA:+"set"}"; then
                      # either the root ca key and password files both exist, or are both missing
                      if test -r "$rootCAKeyPasswordPath" && test -r "$rootCAKeyPath"; then
                          info "both \$rootCAKeyPasswordPath and \$rootCAKeyPath exist and are readable files"
                      elif { ! test -r "$rootCAKeyPasswordPath"; } && { ! test -r "$rootCAKeyPath"; }; then
                          info "both \$rootCAKeyPasswordPath and \$rootCAKeyPath are both missing; will create them"
                      elif test -r "$rootCAKeyPasswordPath" && { ! test -r "$rootCAKeyPath"; }; then
                          markError "invalid state where \$rootCAKeyPasswordPath is a readable file, and \$rootCAKeyPath isn't"
                      elif { ! test -r "$rootCAKeyPasswordPath"; } && test -r "$rootCAKeyPath"; then
                          markError "invalid state where \$rootCAKeyPasswordPath is not a readable file, and \$rootCAKeyPath is"
                      else
                          markError "invalid state with \$rootCAKeyPasswordPath and \$rootCAKeyPath"
                          ls --directory -lh "$rootCAKeyPasswordPath" "$rootCAKeyPath" || true
                      fi
                  fi
                  # either the intermediate ca key and password files both exist, or are both missing
                  if test -r "$intermediateCAKeyPasswordPath" && test -r "$intermediateCAKeyPath"; then
                      info "both \$intermediateCAKeyPasswordPath and \$intermediateCAKeyPath exist and are readable files"
                  elif { ! test -r "$intermediateCAKeyPasswordPath"; } && { ! test -r "$intermediateCAKeyPath"; }; then
                      info "both \$intermediateCAKeyPasswordPath and \$intermediateCAKeyPath are both missing; will create them"
                  elif test -r "$intermediateCAKeyPasswordPath" && { ! test -r "$intermediateCAKeyPath"; }; then
                      markError "invalid state where \$intermediateCAKeyPasswordPath is a readable file, and \$intermediateCAKeyPath isn't"
                  elif { ! test -r "$intermediateCAKeyPasswordPath"; } && test -r "$intermediateCAKeyPath"; then
                      markError "invalid state where \$intermediateCAKeyPasswordPath is not a readable file, and \$intermediateCAKeyPath is"
                  else
                      markError "invalid state with \$intermediateCAKeyPasswordPath and \$intermediateCAKeyPath"
                      ls --directory -lh "$intermediateCAKeyPasswordPath" "$intermediateCAKeyPath" || true
                  fi

                  # the existence and validity of the root ca certificate is
                  # always checked, because it must always be present
                  if ROOT_CERT_FINGERPRINT="$(step certificate fingerprint "''${rootCACertPath:?"\$rootCACertPath not set"}")"; then
                      info "the fingerprint for the root certificate is: $ROOT_CERT_FINGERPRINT"
                  else
                      markError "cannot get fingerprint of root ca certificate"
                  fi

                  if test -n "''${ENCOUNTERED_ERROR:+"set"}"; then
                      reportMarkedError "error(s) encountered while checking paths"
                  else
                      info "all paths are okay"
                  fi

                  ## key and password validity checks and creation logic ##
                  # 1) if the intermediate ca password, key, and cert paths do exist
                  #   a) check that they decrypt using the expected names
                  #   b) verify that the certificate was signed by the root ca certificate
                  #   c) sign something to check that the key and password can be used
                  # 2) if the intermediate ca password and key paths don't exist
                  #   a) generate a password for the intermediate key
                  #   b) if we're a root ca
                  #      i)   create a key and certificate for the intermediate ca
                  #      ii)  encrypt them and the password to the intermediate paths
                  #   c) if we're an intermediate ca
                  #     i)   run bootstrap using the root ca cert (always provided)
                  #     ii)  use acme to request a certificate from the root ca
                  #     iii) use x5c and the previous certificate to request an
                  #          ssh host key from the root ca
                  #     iv)  use ssh host key to retrieve the root ca's
                  #          ssh host and user ca keys
                  #     v)   verify ssh keys work by changing password from
                  #          blank to blank
                  #     vi)  encrypt all to appropriate paths

                  # 1) if the intermediate ca password and key paths do exist
                  if \
                      test -r "$intermediateCAKeyPasswordPath" && \
                      test -r "$intermediateCAKeyPath"
                  then
                      # 1.a) check that the intermediate ca key password decrypts using the expected name
                      if ! systemd-creds \
                          --with-name="$intermediateCAKeyPasswordCredentialName" \
                          decrypt \
                          "$intermediateCAKeyPasswordPath" \
                          > /dev/null
                      then
                          error "issue decrypting the intermediate ca key password file: $intermediateCAKeyPasswordPath"
                      else
                          info "intermediate ca key password decrypts correctly"
                      fi

                      # 1.a) check that the intermediate ca key decrypts using the expected name
                      if ! systemd-creds \
                          --with-name="$intermediateCAKeyCredentialName" \
                          decrypt \
                          "$intermediateCAKeyPath" \
                          > /dev/null
                      then
                          error "issue decrypting the intermediate ca key file: $intermediateCAKeyPath"
                      else
                          info "intermediate ca key decrypts correctly"
                      fi

                      # 1.b) verify that the root ca certificate signed the
                      # intermediate ca certificate
                      if ! step certificate verify \
                          "$intermediateCACertPath" \
                          --roots="$rootCACertPath" \
                          --verbose
                      then
                          markError "intermediate ca certificate didn't validate against the root cert"
                          set | grep -E '^intermediateCACertPath=' || echo 'intermediateCACertPath='
                          set | grep -E '^rootCACertPath=' || echo 'rootCACertPath='
                      fi

                      # 1.c) sign something with the intermediate key to check
                      # that both it and the password are valid
                      info "creating a test certificate to verify intermediate ca works"
                      TEST_CERT_DIR="$TMPDIR/test_cert"
                      mkdir -vp "$TEST_CERT_DIR"
                      TEST_PASSWORD_PATH="$TEST_CERT_DIR/test_key_password"
                      info "using test password in: $TEST_PASSWORD_PATH"
                      echo 'insecure' > "$TEST_PASSWORD_PATH"
                      step certificate create \
                          'test.example.test' \
                          "$TEST_CERT_DIR/test.crt" \
                          "$TEST_CERT_DIR/test_key" \
                          --password-file="$TEST_CERT_DIR/test_key_password" \
                          --kty=OKP --curve=Ed25519 \
                          --profile=leaf \
                          --not-before=+1y \
                          --not-after=-1y \
                          --ca="$intermediateCACertPath" \
                          --ca-key="$intermediateCAKeyPath" \
                          --ca-password-file="$intermediateCAKeyPasswordPath"
                      step certificate verify "$TEST_CERT_DIR/test.crt" --roots="$intermediateCACertPath" --verbose
                      rm -rf "$TEST_CERT_DIR"

                  # 2.a) if the intermediate ca password and key paths don't exist...
                  elif ! {
                      test -r "$intermediateCAKeyPasswordPath" \
                      && \
                      test -r "$intermediateCAKeyPath"
                  }; then
                      # 2.a) generate a password for the intermediate key
                      INTERMEDIATE_CA_KEY_PASSWORD_PATH="$STATE_DIRECTORY/secrets/unencrypted-intermediate-ca-key-password"
                      export INTERMEDIATE_CA_KEY_PASSWORD_PATH
                      mkdir -p "$(dirname "$INTERMEDIATE_CA_KEY_PASSWORD_PATH")"
                      info "generating a password for the intermediate ca key at: $INTERMEDIATE_CA_KEY_PASSWORD_PATH"
                      step crypto rand 32 --format=ascii > "$INTERMEDIATE_CA_KEY_PASSWORD_PATH"

                      if test -n "''${beRootCA:+"set"}"; then
                          # 2.b.i) create a key and certificate for the intermediate ca, using the root ca
                          INTERMEDIATE_CA_TEMPLATE="$TMPDIR/intermediate_ca.tmpl"
                          info "extracting the intermediate ca template in $CA_CONFIG to: $INTERMEDIATE_CA_TEMPLATE"
                          jq \
                              --null-input \
                              --exit-status \
                              --raw-output \
                              -- \
                              '.templates.custom.intermediate' \
                              "$CA_CONFIG" \
                              > "$INTERMEDIATE_CA_TEMPLATE"
                          info "this is the template that will be used to create the intermediate ca:"
                          jq --monochrome-output --null-input . "$INTERMEDIATE_CA_TEMPLATE"
                          INTERMEDIATE_CA_KEY_PATH="$STATE_DIRECTORY/secrets/unencrypted-intermediate-ca-key"
                          if test -e "$INTERMEDIATE_CA_KEY_PATH"; then
                              error "found an existing intermediate ca kay at $INTERMEDIATE_CA_KEY_PATH"
                          else
                              info "using this as the temporary intermediate ca key path: $INTERMEDIATE_CA_KEY_PATH"
                          fi
                          info "creating an intermediate ca key at: $INTERMEDIATE_CA_KEY_PATH"
                          info "and creating an intermediate ca certificate at: $intermediateCACertPath"
                          step certificate create \
                              "$ROOT_CA_URL" \
                              "$intermediateCACertPath" \
                              "$INTERMEDIATE_CA_KEY_PATH" \
                              --password-file="$INTERMEDIATE_CA_KEY_PASSWORD_PATH" \
                              --kty=OKP --curve=Ed25519 \
                              --template="$INTERMEDIATE_CA_TEMPLATE" \
                              --not-before="$STEP_VALIDITY_NOT_BEFORE" \
                              --not-after="$STEP_VALIDITY_NOT_AFTER" \
                              --ca="$rootCACertPath" \
                              --ca-key="$rootCAKeyPath" \
                              --ca-password-file="$rootCAKeyPasswordPath"

                          # 2.b.ii) if the intermediate key and certificate are
                          # missing, and we're a root ca, encrypt the
                          # intermediate ca password and key to the
                          # intermediate paths
                          info "encrypting the intermediate ca key password (\$INTERMEDIATE_CA_KEY_PASSWORD_PATH=$INTERMEDIATE_CA_KEY_PASSWORD_PATH) and storing it here: \$intermediateCAKeyPasswordPath=$intermediateCAKeyPasswordPath)"
                          systemd-creds \
                              --with-key=auto \
                              --not-after=+24h \
                              --name="$intermediateCAKeyPasswordCredentialName" \
                              encrypt \
                              "$INTERMEDIATE_CA_KEY_PASSWORD_PATH"
                              "$intermediateCAKeyPasswordPath"
                          # NOTE::CONTINUE check that the credentials decrypt
                          # to the same hash as the unencrypted, then delete
                          # the unencrypted ones
                          info "encrypting the intermediate ca key (\$INTERMEDIATE_CA_KEY_PATH=$INTERMEDIATE_CA_KEY_PATH) and storing it here (\$intermediateCAKeyPath=$intermediateCAKeyPath)"
                          systemd-creds \
                              --with-key=auto \
                              --not-after=+24h \
                              --name="$intermediateCAKeyCredentialName" \
                              encrypt \
                              "$INTERMEDIATE_CA_KEY_PATH"
                              "$intermediateCAKeyPath"
                      else
                          # 2.c.i) if the intermediate ca password and key are
                          # missing, and we're an intermediate ca, run
                          # bootstrap using the always-available root
                          # certificate
                          # NOTE::QUESTION I don't know if this is necessary
                          info "bootstrapping step clients with \$STEPPATH=$STEPPATH"
                          step ca bootstrap \
                              --ca-url="''${ROOT_CA_URL:?"\$ROOT_CA_URL not set"}" \
                              --fingerprint="$ROOT_CERT_FINGERPRINT"

                          # 2.b.ii) if the intermediate ca password and ket are
                          # missing, and we're an intermediate ca, use acme to
                          # request an intermediate ca certificate from the
                          # root ca's intermediate ca
                          INTERMEDIATE_CA_KEY_PATH="$STATE_DIRECTORY/secrets/unencrypted-intermediate-ca-key"
                          if test -e "$INTERMEDIATE_CA_KEY_PATH"; then
                              error "found an existing intermediate ca kay at $INTERMEDIATE_CA_KEY_PATH"
                          else
                              info "using this as the temporary intermediate ca key path: $INTERMEDIATE_CA_KEY_PATH"
                          fi
                          step ca certificate \
                              "$INTERMEDIATE_CA_FQDN" \
                              "$intermediateCACertPath" \
                              "$INTERMEDIATE_CA_KEY_PATH" \
                              --password-file="$INTERMEDIATE_CA_KEY_PASSWORD_PATH" \
                              --kty=OKP --curve=Ed25519 \
                              --not-before="$STEP_VALIDITY_NOT_BEFORE" \
                              --not-after="$STEP_VALIDITY_NOT_AFTER" \
                              --provisioner=${
                    cfg.settings.authority
                    |> builtins.filter (x: x.type == "ACME")
                    |> builtins.getAttr "name"
                    |> lib.escapeShellArg
                  } \
                              --standalone \
                              --contact=${lib.escapeShellArg cfg.contactEmail} \
                              --console

                          # 2.c.iii) if the intermediate ca password and key are missing, and we're an intermediate ca, use x5c and the previous certificate to request an ssh host key from the root ca
                          SSH_HOST_KEY="$STATE_DIRECTORY/secrets/unencrypted-ssh-host-key"
                          if test -e "$SSH_HOST_KEY"; then
                              error "found an existing ssh host key (not ca): $SSH_HOST_KEY"
                          else
                              info "creating an unencrypted ssh host key (not ca): $SSH_HOST_KEY"
                          fi
                          step ssh certificate \
                              "$INTERMEDIATE_CA_FQDN@$DATETIME" \
                              "$SSH_HOST_KEY" \
                              --no-password --insecure \
                              --kty=OKP --curve=Ed25519 \
                              --host \
                              --host-id=machine \
                              --principal="$INTERMEDIATE_CA_FQDN" \
                              --commane="$INTERMEDIATE_CA_FQDN@$DATETIME" \
                              --not-before="$STEP_VALIDITY_NOT_BEFORE" \
                              --not-after="$STEP_VALIDITY_NOT_AFTER" \
                              --console \
                              --provisioner=${
                    cfg.settings.authority
                    |> builtins.filter (x: x.type == "X5C")
                    |> builtins.getAttr "name"
                    |> lib.escapeShellArg
                  } \
                              --x5c-cert="$intermediateCACertPath" \
                              --x5c-key="$INTERMEDIATE_CA_KEY_PATH" \
                              --no-agent \

                      fi
                  else
                      error "in ensuring that the intermediate ca password and key exist, some combination of conditions was not accounted for"
                  fi

                  ## ssh keys ##
                  # if the host doesn't have a host ssh key, and we're a root ca:
                  # - request a host key from self
                  # - install host key
                  # if the host doesn't have a host ssh key, and we're an intermediate ca:
                  # - request a host key from the ca
                  # - install host key

                  # if there are user and host ssh ca keys, check that they decrypt with the expected names
                  # if there aren't both a user and a host ssh ca key, and we're a root ca:
                  # - create and encrypt user and host ca keys
                  # if there aren't both a user and a host ssh ca key, and we're an intermediate ca:
                  # - request a user ssh key
                  # - scp both the user and host ca keys over
                  # - encrypt both
                '';
            }
          );
      };
    };

    systemd.services.step-ca = {
      serviceConfig = {
        StateDirectory = config.systemd.services.step-ca.name;
        Environment = ["STEPPATH=%S"];
        ReadWritePaths = [
          "" # override upstream
          EXPECTED_STATE_DIRECTORY
        ];
        ReadOnlyPaths = [
          configDir
          #"%d"
        ];

        LoadCredentialEncrypted = let
          makeCred = path: "${baseNameOf path}:${path}";
          intermediateCAKey = makeCred config.services.step-ca.settings.key;
          intermediateCAKeyPassword = makeCred cfg.intermediateCAKeyPasswordPath;
          sshHostCAKey = makeCred config.services.step-ca.settings.ssh.hostKey;
          sshUserCAKey = makeCred config.services.step-ca.settings.ssh.hostKey;
        in [
          intermediateCAKey
          intermediateCAKeyPassword
          sshHostCAKey
          sshUserCAKey
        ];

        ExecStartPre = [
          "systemd-creds list"
          (
            let
              STATE_DIRECTORY = config.systemd.services.step-ca.serviceConfig.StateDirectory;
            in
              ''sh -c 'if test "$STATE_DIRECTORY" != "%S/${STATE_DIRECTORY}";''
              + " then "
              + ''echo "\$STATE_DIRECTORY is not what it was expected to be"; exit 1;''
              + " fi'"
          )
        ];
        ExecStart = [
          "" # override upstream
          "${lib.getExe config.services.step-ca.package} ${
            config.systemd.services.step-ca.restartTriggers |> builtins.head
          } --password-file=\$CREDENTIALS_DIRECTORY/${
            baseNameOf cfg.intermediateCAKeyPasswordPath |> lib.escapeShellArg
          }"
        ];
      };
    };
  };
}
