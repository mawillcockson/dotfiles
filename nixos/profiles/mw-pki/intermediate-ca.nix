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

  LoadCredentialEncryptedIntermediateCAKey = "${baseNameOf config.services.step-ca.settings.key}:${config.services.step-ca.settings.key}";
  LoadCredentialEncryptedIntermediateCAKeyPassword = "${baseNameOf cfg.intermediateCAKeyPasswordPath}:${cfg.intermediateCAKeyPasswordPath}";
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
    root-ca-url = lib.mkOption {
      type = lib.types.str;
      description = "URL the root ca is reachable at";
      example = lib.literalExpression ''"https://ca.example.com:8229"'';
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
              ];
              runtimeEnv =
                {
                  CONFIG_DIR = configDir;
                  SCRIPT_NAME = script_name;
                  inherit
                    EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY
                    EXPECTED_CREDENTIALS_DIRECTORY
                    EXPECTED_STATE_DIRECTORY
                    ;
                  ROOT_CA_URL = cfg.root-ca-url;
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

                  if test -z "''${EXPECTED_CREDENTIALS_DIRECTORY:+"set"}"; then
                      markError "expected \$EXPECTED_CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                  fi
                  # NOTE::CONTINUE add into these path checks, the checks for
                  # the password and key paths as well, doubling as checks that
                  # the variables exist
                  if SYSTEMD_CREDENTIALS_DIRECTORY="$(systemd-path system-credential-store)"; then
                      if test "''${EXPECTED_CREDENTIALS_DIRECTORY-}" != "$SYSTEMD_CREDENTIALS_DIRECTORY"; then
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
                  else
                      warn 'systemd-path returned an error for `system-credetial-store`'
                  fi

                  if test -z "''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY:+"set"}"; then
                      markError "expected \$EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                  fi
                  if SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY="$(systemd-path system-credential-store-encrypted)"; then
                      if test "''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY-}" != "$SYSTEMD_ENCRYPTED_CREDENTIALS_DIRECTORY"; then
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
                  else
                      markError 'systemd-path returned an error for `system-credential-store-encrypted`'
                  fi

                  if test -n "''${beRootCA:+"set"}"; then
                      if test -z "''${rootCAKeyPasswordPath:+"set"}"; then
                          markError "\$rootCAKeyPasswordPath not set"
                      else
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
                          if
                            test \
                              "''${rootCAKeyPasswordPath:?"\$rootCAKeyPasswordPath is not set"}" \
                              = \
                              "''${rootCAKeyPasswordPath#"$EXPECTED_CREDENTIALS_DIRECTORY"}"
                          then
                              markError "the \$rootCAKeyPasswordPath is not in the \$EXPECTED_CREDENTIALS_DIRECTORY"
                          else
                              info "the \$rootCAKeyPasswordPath is in the \$EXPECTED_CREDENTIALS_DIRECTORY"
                          fi
                      fi
                      set | grep -E '^EXPECTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^rootCAKeyPasswordPath=' || echo 'rootCAKeyPasswordPath='

                      if test -z "''${rootCAKeyPath:+"set"}"; then
                          markError "\$rootCAKeyPath not set"
                      else
                          if test \
                              "''${rootCAKeyPath:?"\$rootCAKeyPath is not set"}" \
                              = \
                              "''${rootCAKeyPath#"$EXPECTED_CREDENTIALS_DIRECTORY"}"
                          then
                              markError "the \$rootCAKeyPath is not in the \$EXPECTED_CREDENTIALS_DIRECTORY"
                          else
                              info "the \$rootCAKeyPath is in the \$EXPECTED_CREDENTIALS_DIRECTORY"
                          fi
                      fi
                      set | grep -E '^EXPECTED_CREDENTIALS_DIRECTORY=' || echo 'EXPECTED_CREDENTIALS_DIRECTORY='
                      set | grep -E '^rootCAKeyPath=' || echo 'rootCAKeyPath='
                  fi

                  # these are always tested, because they're always used
                  if test -z "''${intermediateCAKeyPasswordPath:+"set"}"; then
                      markError "\$intermediateCAKeyPasswordPath not set"
                  else
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
                  # NOTE::CONTINUE also need to check the user and host ssh ca key paths

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

                  if test -n "''${ENCOUNTERED_ERROR:+"set"}"; then
                      reportMarkedError "error(s) encountered while checking paths"
                  else
                      info "all paths are okay"
                  fi

                  # NOTE::CONTINUE do these "variable existence checks" while
                  # also checking the contents, with the above
                  if test -n "''${beRootCA:+"set"}"; then
                      info "\$rootCAKeyPasswordPath=''${rootCAKeyPasswordPath:?"\$rootCAKeyPasswordPath not set"}"
                      # not needed, because the credential isn't provided through
                      # systemd's Load/SetCredential, so the credential name is
                      # never needed
                      #info "\$rootCAKeyPasswordCredentialName=''${rootCAKeyPasswordCredentialName:?"\$rootCAKeyPasswordCredentialName not set"}"
                      info "\$rootCAKeyPath=''${rootCAKeyPath:?"\$rootCAKeyPath not set"}"
                      #info "\$rootCAKeyCredentialName=''${rootCAKeyCredentialName:?"\$rootCAKeyCredentialName not set"}"
                  fi
                  info "\$intermediateCAKeyPasswordPath=''${intermediateCAKeyPasswordPath:?"\$intermediateCAKeyPasswordPath not set"}"
                  info "\$intermediateCAKeyPasswordCredentialName=''${intermediateCAKeyPasswordCredentialName:?"\$intermediateCAKeyPasswordCredentialName not set"}"
                  info "\$intermediateCAKeyPath=''${intermediateCAKeyPath:?"\$intermediateCAKeyPath not set"}"
                  info "\$intermediateCAKeyCredentialName=''${intermediateCAKeyCredentialName:?"\$intermediateCAKeyCredentialName not set"}"
                  info "\$intermediateCACertPath=''${intermediateCACertPath:?"\$intermediateCACertPath it not set"}"

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
                  if ROOT_CERT_FINGERPRINT="$(step certificate fingerprint "''${rootCACertPath:?"\$rootCACertPath not set"}")"; then
                      info "the fingerprint for the root certificate is: $ROOT_CERT_FINGERPRINT"
                  else
                      markError "cannot get fingerprint of root ca certificate"
                  fi

                  if test -n "''${ENCOUNTERED_ERROR:+"set"}"; then
                      reportMarkedError "error(s) encountered while checking paths"
                  else
                      info "all paths so far appear to be okay"
                  fi

                  ## key and password validity checks ##
                  # 1) if the intermediate ca password and key paths do exist
                  #   b) check that they decrypt using the expected names
                  #   a) if we're a root ca, decrypt and warn if either the
                  #   provided password or key differ from the (unencrypted)
                  #   root ca equivalent's existing ones
                  # 2) if the intermediate ca password and key paths don't exist
                  #   a) if we're a root ca, encrypt the provided root ca password and key to the intermediate paths
                  #   b) if we're an intermediate ca
                  #     i)   run bootstrap using the root ca cert (always provided)
                  #     ii)  generate a password for the intermediate key
                  #     iii) create an intermediate key and certificate signing request
                  #     iv)  submit a CSR for the certificate to the root ca
                  #     v)   encrypt and store the password and key
                  #     vi)  store the signed certificate

                  # 1) if the intermediate ca password and key paths do exist
                  if \
                      test -r "$intermediateCAKeyPasswordPath" && \
                      test -r "$intermediateCAKeyPath"
                  then
                      # 1.b) check that the intermediate ca key password decrypts using the expected name
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

                      # 1.b) check that the intermediate ca key decrypts using the expected name
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
                      # 1.a) if we're a root ca, decrypt and warn if either the
                      # provided password or key differ from the (unencrypted)
                      # root ca equivalent's existing ones
                      if test -n "''${beRootCA:+"set"}"; then
                          if ! INTERMEDIATE_PASSWORD_HASH="$(systemd-creds \
                              --with-name="$intermediateCAKeyPasswordCredentialName" \
                              decrypt \
                              "$intermediateCAKeyPasswordPath" \
                              | cksum \
                                  --algorithm=sha2 \
                                  --length=512 \
                                  --base64 \
                                  --tag \
                                  -
                          )"
                          then
                              error "issue with hashing the intermediate ca key password"
                          # using file redirection so that cksum can read from
                          # standard input, because it includes the filename in its
                          # output, and that would be different, even if the hashes
                          # were the same
                          elif ! ROOT_PASSWORD_HASH="$(cksum \
                              --algorithm=sha2 \
                              --length=512 \
                              --base64 \
                              --tag \
                              - \
                              < "$rootCAKeyPasswordPath")"
                          then
                              error "issue hashing root ca key password"
                          elif test "$INTERMEDIATE_PASSWORD_HASH" = "$ROOT_PASSWORD_HASH"; then
                              info "intermediate and root ca key passwords hash to the same value"
                          else
                              error "an error was encountered while checking if the intermediate and root ca key passwords hash to the same value"
                          fi

                          if ! INTERMEDIATE_KEY_HASH="$(systemd-creds \
                              --with-name="$intermediateCAKeyCredentialName" \
                              decrypt \
                              "$intermediateCAKeyPath" \
                              | cksum \
                                  --algorithm=sha2 \
                                  --length=512 \
                                  --base64 \
                                  --tag \
                                  -
                          )"
                          then
                              error "issue with hashing the intermediate ca key"
                          # using file redirection so that cksum can read from
                          # standard input, because it includes the filename in its
                          # output, and that would be different, even if the hashes
                          # were the same
                          elif ! ROOT_KEY_HASH="$(cksum \
                              --algorithm=sha2 \
                              --length=512 \
                              --base64 \
                              --tag \
                              - \
                              < "$rootCAKeyPath")"
                          then
                              error "issue hashing root ca key"
                          elif test "$INTERMEDIATE_KEY_HASH" = "$ROOT_KEY_HASH"; then
                              info "intermediate and root ca keys hash to the same value"
                          else
                              error "an error was encountered while checking if the intermediate and root ca keys hash to the same value"
                          fi
                      fi
                  # 2.a) if the intermediate ca password and key paths don't
                  # exist, if we're a root ca, encrypt the provided root ca
                  # password and key to the intermediate paths
                  elif ! {
                      test -r "$intermediateCAKeyPasswordPath" \
                      && \
                      test -r "$intermediateCAKeyPath"
                  } && test -n "''${beRootCA:+"set"}"; then
                      info "encrypting the root ca key password (\$rootCAKeyPasswordPath=$rootCAKeyPasswordPath) and storing it as the intermediate ca key password (\$intermediateCAKeyPasswordPath=$intermediateCAKeyPasswordPath)"
                      systemd-creds \
                          --with-key=auto \
                          --not-after=+24h \
                          --name="$intermediateCAKeyPasswordCredentialName" \
                          encrypt \
                          "$rootCAKeyPasswordPath"
                          "$intermediateCAKeyPasswordPath"
                      info "encrypting the root ca key (\$rootCAKeyPath=$rootCAKeyPath) and storing it as the intermediate ca key (\$intermediateCAKeyPath=$intermediateCAKeyPath)"
                      systemd-creds \
                          --with-key=auto \
                          --not-after=+24h \
                          --name="$intermediateCAKeyCredentialName" \
                          encrypt \
                          "$rootCAKeyPath"
                          "$intermediateCAKeyPath"
                  # 2.b) if the intermediate ca password and key paths don't exist, and we're an intermediate ca
                  elif ! {
                      test -r "$intermediateCAKeyPasswordPath" \
                      && \
                      test -r "$intermediateCAKeyPath"
                  } && test -z "''${beRootCA:+"set"}"; then
                      # 2.b.i) run bootstrap using the root ca cert (always provided)
                      # I don't know if this is necessary
                      info "bootstrapping step clients with \$STEPPATH=''${STEPPATH:?"\$STEPPATH not set"}"
                      export STEPPATH
                      step ca bootstrap \
                          --ca-url="''${ROOT_CA_URL:?"\$ROOT_CA_URL not set"}" \
                          --fingerprint="$ROOT_CERT_FINGERPRINT"

                      # 2.b.ii) generate a password for the intermediate key
                      INTERMEDIATE_CA_KEY_PASSWORD_PATH="$STATE_DIRECTORY/secrets/unencrypted-intermediate-ca-key-password"
                      export INTERMEDIATE_CA_KEY_PASSWORD_PATH
                      mkdir -p "$(dirname "$INTERMEDIATE_CA_KEY_PASSWORD_PATH")"
                      info "generating a password for the intermediate ca key at: $INTERMEDIATE_CA_KEY_PASSWORD_PATH"
                      step crypto rand 32 --format=ascii > "$INTERMEDIATE_CA_KEY_PASSWORD_PATH"

                      # 2.b.iii) create an intermediate key and certificate
                      INTERMEDIATE_CA_CSR="$STATE_DIRECTORY/csr/intermediate-csr"
                      export INTERMEDIATE_CA_CSR
                      if test -e "$INTERMEDIATE_CA_CSR"; then
                          error "found an existing certificate signing request for the intermediate ca at: $INTERMEDIATE_CA_CSR"
                      fi
                      INTERMEDIATE_CA_KEY_PATH="$STATE_DIRECTORY/secrets/intermediate-ca-key"
                      if test -e "$INTERMEDIATE_CA_KEY_PATH"; then
                          error "found an existing intermediate ca kay at $INTERMEDIATE_CA_KEY_PATH"
                      fi
                      info "creating a key for the intermediate ca at: $INTERMEDIATE_CA_KEY_PATH"
                      info "also creating a csr at: $INTERMEDIATE_CA_CSR"
                      step certificate create \
                          'mw pki Intermediate CA' \
                          "$INTERMEDIATE_CA_CSR" \
                          "$INTERMEDIATE_CA_KEY_PATH" \
                          --csr \
                          --kty=OKP \
                          --profile=intermediate-ca \
                          --password-file="$INTERMEDIATE_CA_KEY_PASSWORD_PATH" \
                          --not-before=-10m \
                          --not-after="$((24 * 365))h"

                      # 2.b.iv) submit a CSR for the certificate to the root ca
                      # NOTE::CONTINUE
                      # 2.b.v) encrypt and store the password and key
                      # 2.b.vi) store the signed certificate
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

                  info "\$sshHostCAKeyPath=''${sshHostCAKeyPath:?"\$sshHostCAKeyPath not set"}"
                  info "\$sshHostCAKeyCredentialName=''${sshHostCAKeyCredentialName:?"\$sshHostCAKeyCredentialName not set"}"
                  info "\$sshUserCAKeyPath=''${sshUserCAKeyPath:?"\$sshUserCAKeyPath not set"}"
                  info "\$sshUserCAKeyCredentialName=''${sshUserCAKeyCredentialName:?"\$sshUserCAKeyCredentialName not set"}"
                  info "\$sshHostKeyPath=''${sshHostKeyPath:?"\$sshHostKeyPath not set"}"
                  info "\$sshHostKeyCredentialName=''${sshHostKeyCredentialName:?"\$sshHostKeyCredentialName not set"}"
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

        LoadCredentialEncrypted = [
          LoadCredentialEncryptedIntermediateCAKeyPassword
          LoadCredentialEncryptedIntermediateCAKey
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
