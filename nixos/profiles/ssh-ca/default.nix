{
  config,
  lib,
  pkgs,
  ...
}: let
  dbDir = "/var/lib/${config.systemd.services.step-ca.serviceConfig.StateDirectory}";
  # NOTE::BUG causes an infinite recursion
  #configDir = config.systemd.services.step-ca.restartTriggers |> builtins.head |> builtins.dirOf;
  configDir = "/etc/smallstep";
  step-ca-init = pkgs.writeShellApplication {
    name = "step-ca-init.sh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
      pkgs.step-ca
      pkgs.step-cli
      pkgs.jq
      pkgs.openssh
    ];
    runtimeEnv = {
      CONFIG_DIR = configDir;
      LOG_SH = log-sh;
    };
    text = builtins.readFile ./step-ca-init.sh;
  };
  step-ca-init-script = "${step-ca-init}/bin/${step-ca-init.name}";
  step-ca-init-make-creds = pkgs.writeShellApplication {
    name = "step-ca-init-make-creds.sh";
    runtimeInputs = [
      pkgs.systemd
      log-sh
    ];
    runtimeEnv = {
      CONFIG_DIR = configDir;
    };
    text = builtins.readFile ./step-ca-init-make-creds.sh;
  };
  step-ca-init-make-creds-script = "${step-ca-init-make-creds}/bin/${step-ca-init-make-creds.name}";
  step-ca.service = config.systemd.services.step-ca.name + ".service";
  log-sh = pkgs.writeTextFile {
    name = "log.sh";
    executable = true;
    preferLocalBuild = false;
    allowSubstitutes = true;
    text = builtins.readFile ../../../debian/usr/local/share/sh/log.sh;
    checkPhase = ''
      runHook preCheck
      ${pkgs.stdenv.shellDryRun} "$target"
      ${lib.getExe pkgs.shellcheck-minimal} --shell=sh "$target"
      runHook postCheck
    '';
  };
in {
  imports = [../server.nix];

  services.step-ca = {
    settings = {
      db = {
        badgerFileLoadingMode = "";
        dataSource = "${dbDir}/db";
        type = "badgerv2";
      };
      # these are created by step-ca-init.service, prior to step-ca.service running:
      # - root
      # - crt
      # - key
      # - ssh
      root = "${configDir}/certs/root_ca.crt";
      crt = "${configDir}/certs/intermediate_ca.crt";
      key = "${configDir}/secrets/intermediate_ca_key";
      ssh = {
        hostKey = "${configDir}/secrets/ssh_host_ca_key";
        userKey = "${configDir}/secrets/ssh_user_ca_key";
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
    enable = true;
    openFirewall = true;
    address = "127.0.0.1";
    port = 52086;
  };

  systemd.services.step-ca = {
    serviceConfig = {
      # services.step-ca overrides the upstread one, which itself uses
      # ReadWriteDirectories, which I don't know about
      ReadWritePaths = [
        ""
        dbDir
      ];
      ReadOnlyPaths = [
        configDir
        #"%d"
      ];
      LoadCredentialEncrypted = "step-ca_password";
      ExecStartPre = ["systemd-creds list"];
      ExecStart = [
        ""
        "${config.services.step-ca.package}/bin/step-ca ${
          config.systemd.services.step-ca.restartTriggers |> builtins.head
        } --password-file=\${CREDENTIALS_DIRECTORY}/step-ca_password"
      ];
    };
  };

  systemd.services.step-ca-init = {
    name = "step-ca-init.service";
    description = "setup step-ca for the test environment";
    wantedBy = ["multi-user.target"];
    wants = ["first-boot-complete.target"];
    before = [
      "first-boot-complete.target"
      step-ca.service
    ];
    unitConfig = {
      #ConditionFirstBoot = true;
      JoinsNamespaceOf = [step-ca.service];
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = config.systemd.services.step-ca.serviceConfig.User;
      Group = config.systemd.services.step-ca.serviceConfig.Group;
      DynamicUser = true;
      ExecStartPre = ["systemd-creds list"];
      LoadCredentialEncrypted = "step-ca_password";
      StateDirectory = config.systemd.services.step-ca.serviceConfig.StateDirectory;
      # Is this necessary?
      #ReadWritePaths = ["%S/${config.systemd.services.step-ca-init.serviceConfig.StateDirectory}"];
    };
    script = step-ca-init-script;
    enableStrictShellChecks = true;
    # I don't think this is necessary, since the script includes `runtimeInputs`
    #path = [
    #  pkgs.step-ca
    #  pkgs.step-cli
    #];
  };

  systemd.services.step-ca-init-make-creds = {
    name = "step-ca-init-make-creds.service";
    description = "create credentials for step-ca-init.sh";
    wantedBy = ["multi-user.target"];
    wants = ["first-boot-complete.target"];
    before = [
      "first-boot-complete.target"
      config.systemd.services.step-ca-init.name
    ];
    unitConfig = {
      #ConditionFirstBoot = true;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = config.systemd.services.step-ca-init-make-creds.name;
    };
    script = step-ca-init-make-creds-script;
    enableStrictShellChecks = true;
  };

  #virtualisation.vmVariant = vmVariant;
  #virtualisation.vmVariantWithBootLoader = vmVariant;

  # I think services.step-ca.enable pulls in the necessary packages already
  environment = {
    systemPackages = [
      pkgs.step-ca
      pkgs.step-cli
      log-sh
    ];
  };
}
