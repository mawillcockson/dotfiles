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

  # canonicalize it here instead of using `basename` in the script, so it's
  # always the same
  rootCAKeyPasswordCredentialName = baseNameOf cfg.rootCAKeyPasswordPath;
  LoadCredentialRootCAKeyPassword = "${rootCAKeyPasswordCredentialName}:${cfg.rootCAKeyPasswordPath}";
  rootCAKeyCredentialName = baseNameOf cfg.rootCAKeyPath;
  LoadCredentialRootCAKey = "${rootCAKeyCredentialName}:${cfg.rootCAKeyPath}";

  intermediateCAKeyPath = config.services.step-ca.settings.key;
  intermediateCAKeyCredentialName = baseNameOf cfg.intermediateCAKeyPasswordPath;
  LoadCredentialEncryptedIntermediateCAKey = "${intermediateCAKeyCredentialName}:${intermediateCAKeyPath}";
  intermediateCAKeyPasswordCredentialName = baseNameOf cfg.intermediateCAKeyPasswordPath;
  LoadCredentialEncryptedIntermediateCAKeyPassword = "${intermediateCAKeyPasswordCredentialName}:${cfg.intermediateCAKeyPasswordPath}";

  filterNull = builtins.filter (x: isNull x -> false);

  LoadCredential =
    [
      (
        if cfg.beRootCA
        then LoadCredentialRootCAKeyPassword
        else null
      )
      (
        if cfg.beRootCA
        then LoadCredentialRootCAKey
        else null
      )
    ]
    |> filterNull;
  LoadCredentialEncrypted =
    [
      (
        if cfg.beRootCA
        then null
        else LoadCredentialEncryptedIntermediateCAKeyPassword
      )
      (
        if cfg.beRootCA
        then null
        else LoadCredentialEncryptedIntermediateCAKey
      )
    ]
    |> filterNull;
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
      default = intermediateCAKeyPath + "_password";
      description = ''
        where the intermediate ca key password is stored
        this must be outside the nix store
        by default, it will be the same as the intermediate ca key, with "_password" appended
      '';
      example = lib.literalExpression ''"/etc/credstore/mw-pki-intermediate-key_password"'';
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
        crt =
          if cfg.beRootCA
          then cfg.rootCACertPath
          else "${EXPECTED_STATE_DIRECTORY}/certs/intermediate_ca.crt";
        key =
          if cfg.beRootCA
          then cfg.rootCAKeyPath
          else "${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY}/secrets/intermediate_ca_key";
        ssh = {
          hostKey = "${EXPECTED_STATE_DIRECTORY}/secrets/ssh_host_ca_key";
          userKey = "${EXPECTED_STATE_DIRECTORY}/secrets/ssh_user_ca_key";
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
        User = step-ca-serviceConfig.User;
        Group = step-ca-serviceConfig.Group;
        DynamicUser = true;

        # these won't exist until after the script, because the script creates
        # these, but I'm hoping their presence will cause the
        # $CREDENTIALS_DIRECTORY variable to be set in the environment
        inherit LoadCredential LoadCredentialEncrypted;

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
                }
                // (
                  if cfg.beRootCA
                  then {
                    inherit (cfg) beRootCA rootCAKeyPasswordPath rootCAKeyPath;
                  }
                  else {
                    inherit (cfg) intermediateCAKeyPasswordPath;
                    inherit intermediateCAKeyPath;
                  }
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
                  checkMarkedError() {
                      if test -n "''${ENCOUNTERED_ERROR:+"set"}"; then
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

                  if test -z "''${EXPECTED_CREDENTIALS_DIRECTORY:-}"; then
                      markError "expected \$EXPECTED_CREDENTIALS_DIRECTORY to be set in the environment that this script is run in"
                  fi
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

                  if test -z "''${EXPECTED_ENCRYPTED_CREDENTIALS_DIRECTORY:-}"; then
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
                      warn 'systemd-path returned an error for `system-credential-store-encrypted`'
                  fi

                  if test -n "''${beRootCA:-}"; then
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
                        markError "the \$rootCAKeyPasswordPath is not in the \$CREDENTIALS_DIRECTORY"
                    else
                        info "the \$rootCAKeyPasswordPath is in the \$CREDENTIALS_DIRECTORY"
                    fi
                    set | grep -E '^CREDENTIALS_DIRECTORY=' || echo 'CREDENTIALS_DIRECTORY='
                    set | grep -E '^rootCAKeyPasswordPath=' || echo 'rootCAKeyPasswordPath='

                    if test \
                        "''${rootCAKeyPath:?"\$rootCAKeyPath is not set"}" \
                        = \
                        "''${rootCAKeyPath#"$CREDENTIALS_DIRECTORY"}"
                    then
                        markError "the \$rootCAKeyPath is not in the \$CREDENTIALS_DIRECTORY"
                    else
                        info "the \$rootCAKeyPath is in the \$CREDENTIALS_DIRECTORY"
                    fi
                    set | grep -E '^CREDENTIALS_DIRECTORY=' || echo 'CREDENTIALS_DIRECTORY='
                    set | grep -E '^rootCAKeyPath=' || echo 'rootCAKeyPath='
                  else
                    if test \
                        "''${intermediateCAKeyPasswordPath:?"\$intermediateCAKeyPasswordPath is not set"}" \
                        = \
                        "''${intermediateCAKeyPasswordPath#"$CREDENTIALS_DIRECTORY"}"
                    then
                        markError "the \$intermediateCAKeyPasswordPath is not in the \$CREDENTIALS_DIRECTORY"
                    else
                        info "the \$intermediateCAKeyPasswordPath is in \$CREDENTIALS_DIRECTORY"
                    fi
                    set | grep -E '^CREDENTIALS_DIRECTORY=' || echo 'CREDENTIALS_DIRECTORY='
                    set | grep -E '^intermediateCAKeyPasswordPath=' || echo 'intermediateCAKeyPasswordPath='

                    if test \
                        "''${intermediateCAKeyPath:?"\$intermediateCAKeyPath is not set"}" \
                        = \
                        "''${intermediateCAKeyPath#"$CREDENTIALS_DIRECTORY"}"
                    then
                        markError "the \$intermediateCAKeyPath is not in the \$CREDENTIALS_DIRECTORY"
                    else
                        info "the \$intermediateCAKeyPath is in \$CREDENTIALS_DIRECTORY"
                    fi
                    set | grep -E '^CREDENTIALS_DIRECTORY=' || echo 'CREDENTIALS_DIRECTORY='
                    set | grep -E '^intermediateCAKeyPath=' || echo 'intermediateCAKeyPath='
                  fi

                  if test -z "''${STATE_DIRECTORY:-}"; then
                      markError "expected \$STATE_DIRECTORY to be set in the environment that this script is run in"
                  fi
                  if test -z "''${EXPECTED_STATE_DIRECTORY:-}"; then
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

                  checkMarkedError "error(s) encountered while checking paths"

                  if test -n "''${beRootCA:+"set"}"; then
                      systemd-creds \
                          --with-key=auto \
                          --no-after=+24h \
                          --name="''${rootCAKeyPasswordCredentialName:?"\$rootCAKeyPasswordCredentialName not set"}" \
                          encrypt \
                          "''${rootCAKeyPasswordPath:?"\$rootCAKeyPasswordPath not set"}"
                  else
                      systemd-creds \
                          --with-key=auto \
                          --no-after=+1y \
                          --name="''${intermediateCAKeyPasswordPath:?"\$intermediateCAKeyPasswordPath not set"}" \
                          encrypt
                  fi
                '';
            }
          );
      };
    };

    systemd.services.step-ca = {
      serviceConfig = {
        StateDirectory = config.systemd.services.step-ca.name;
        ReadWritePaths = [
          "" # override upstream
          EXPECTED_STATE_DIRECTORY
        ];
        ReadOnlyPaths = [
          configDir
          #"%d"
        ];

        LoadCredential =
          [
            (
              if cfg.beRootCA
              then LoadCredentialRootCAKeyPassword
              else null # load intermediateCAKeyPassword
            )
            (
              if cfg.beRootCA
              then LoadCredentialRootCAKey
              else null
            )
          ]
          |> filterNull;
        LoadCredentialEncrypted =
          [
            (
              if cfg.beRootCA
              then null
              else LoadCredentialEncryptedIntermediateCAKeyPassword
            )
            (
              if cfg.beRootCA
              then null
              else LoadCredentialEncryptedIntermediateCAKey
            )
          ]
          |> filterNull;

        ExecStartPre = ["systemd-creds list"];
        ExecStart = [
          "" # override upstream
          "${lib.getExe config.services.step-ca.package} ${
            config.systemd.services.step-ca.restartTriggers |> builtins.head
          } --password-file=\$CREDENTIALS_DIRECTORY/${
            if cfg.beRootCA
            then rootCAKeyPasswordCredentialName
            else intermediateCAKeyPasswordCredentialName |> lib.escapeShellArg
          }"
        ];
      };
    };
  };
}
