{
  self,
  lib,
  pkgs,
  ...
}: let
  rootCAKeyPasswordPath = "root-password-file";
  rootCAKeyPath = "root_ca.key";
  rootCACertPath = "root_ca.crt";
  test-certificates = pkgs.runCommandLocal "test-certificates" {} ''
    mkdir -p "$out"
    printf '%s' 'insecure-root-password' > "$out/${rootCAKeyPasswordPath}"
    ${lib.getExe pkgs.step-cli} certificate create \
        "Example Root CA" \
        "$out/${rootCACertPath}" \
        "$out/${rootCAKeyPath}" \
        --kty=OKP \
        --profile=root-ca \
        --password-file="$out/${rootCAKeyPasswordPath}" \
        --not-before=-10m \
        --not-after="24h"
    # ${lib.getExe pkgs.step-cli} certificate create "Example Intermediate CA 1" $out/intermediate_ca.crt $out/intermediate_ca.key --password-file=$out/intermediate-password-file --ca-password-file=$out/root-password-file --profile intermediate-ca --ca $out/root_ca.crt --ca-key $out/root_ca.key
  '';
  rootCA = {config', ...}: {
    #virtualisation.vlans = [1];
    #services.mw-pki.intermediateCA = {
    #  enable = true;
    #  beRootCA = true;
    #  rootCAKeyPasswordPath = "${test-certificates}/${rootCAKeyPasswordPath}";
    #  rootCAKeyPath = "${test-certificates}/${rootCAKeyPath}";
    #  rootCACertPath = "${test-certificates}/${rootCACertPath}";
    #  root-ca-url = "https://myLaptop:${config'.services.step-ca.port}";
    #  sshHostAllowedDomainNames = ["intermediateCA.local"];
    #  x509AllowedDomainNames = ["intermediateCA.local"];
    #};
    #services.step-ca.settings.dnsNames = [
    #  "localhost"
    #  "myLaptop"
    #];
    imports = [
      #self.nixosModules.mw-pki
    ];
    environment.systemPackages = [
      pkgs.step-ca
      pkgs.step-cli
      (pkgs.writeShellApplication {
        name = "test.sh";
        runtimeInputs = [];
        runtimeEnv = {};
        text = ''
          set -eu
          STEPPATH=/tmp/step-ca
          export STEPPATH
          mkdir -p "$STEPPATH/secrets/"
          echo 'insecure root ca password' > "$STEPPATH/secrets/ca-password.txt"
          echo 'insecure provisioner password' > "$STEPPATH/secrets/provisioner-password.txt"
          step ca init \
              --deployment-type=standalone \
              --root=${test-certificates}/${rootCACertPath} \
              --key=${test-certificates}/${rootCAKeyPath} \
              --key-password-file=${test-certificates}/${rootCAKeyPasswordPath} \
              --ssh \
              --acme \
              --name="test pki" \
              --provisioner="first provisioner" \
              --dns=myLaptop.local \
              --dns=myLaptop \
              --address='[::]:52000' \
              --password-file="$STEPPATH/secrets/ca-password.txt" \
              --provisioner-password-file="$STEPPATH/secrets/provisioner-password.txt"
          step-ca "$STEPPATH/config/ca.json" --password-file="$STEPPATH/secrets/ca-password.txt"
        '';
      })
    ];
  };
  # make it clear how I want to run this
  myLaptop = rootCA;
  intermediateCA = {...}: {
    #virtualisation.vlans = [
    #  1
    #  2
    #];
    imports = [
      #self.nixosModules.mw-pki
    ];
    #services.mw-pki.intermediateCA.enable = true;
    environment.systemPackages = [
      pkgs.step-ca
      pkgs.step-cli
      (pkgs.writeShellApplication {
        name = "test.sh";
        runtimeInputs = [];
        runtimeEnv = {};
        text = ''
          set -eu
          STEPPATH=/tmp/step-cli
          export STEPPATH
          mkdir -p "$STEPPATH/secrets/"
          FINGERPRINT="$(step certificate fingerprint ${lib.escapeShellArg test-certificates}/${rootCACertPath})"
          printf '%s=%s\n' "\$FINGERPRINT" "$FINGERPRINT"
          echo 'insecure password' > "$STEPPATH/secrets/password.txt"
          step ca bootstrap \
              --ca-url=https://myLaptop:52000 \
              --fingerprint="$FINGERPRINT"
          step ca certificate \
              'intermediateCA' \
              "$STEPPATH/certs/intermediate_ca.crt" \
              "$STEPPATH/secrets/intermediate_ca_key" \
              --san=192.168.1.1 \
              --provisioner=acme \
              --contact='test@example.test' \
              --standalone \
              --kty=OKP \
              --curve=Ed25519 \
              --password-file="$STEPPATH/secrets/password.txt"
        '';
      })
    ];
  };
  #server = {...}: {
  #  virtualisation.vlans = [2];
  #  services.mw-pki.server.enable = true;
  #  imports = [self.nixosModules.mw-pki];
  #};
  #client = {...}: {
  #  virtualisation.vlans = [2];
  #  services.mw-pki.client.enable = true;
  #  imports = [self.nixosModules.mw-pki];
  #};
in
  pkgs.testers.runNixOSTest {
    imports = [
      {
        name = "mw-pki: intermediate CA";
        nodes = {inherit myLaptop intermediateCA;};
        testScript =
          /*
          python
          */
          ''
            myLaptop.execute("systemctl is-system-running --wait")
            myLaptop.execute("test.sh >&2 &")
            myLaptop.wait_until_succeeds("pgrep step-ca", timeout=30)
            intermediateCA.execute("systemctl is-system-running --wait")
            intermediateCA.execute("test.sh")
          '';
        #''
        #  intermediateCA.start()
        #  myLaptop.wait_for_unit("mw-pki-rootCA.service")
        #  intermediateCA.succeed(
        #      "sudo -u test -- step ca bootstrap --ca-url=http://myLaptop:${
        #    (lib.nixosSystem {
        #      modules = [self.nixosModules.mw-pki.rootCA];
        #      inherit (pkgs.stdenv.hostPlatform) system;
        #    }).config.services.step-ca.port
        #  } --fingerprint=")
        #  intermediateCA.succeed("check that myLaptop's key is useable")
        #  myLaptop.shutdown()
        #  intermediateCA.shutdown()

        #  # do it again to simulate the computers being restarted
        #  intermediateCA.start()
        #  myLaptop.wait_for_unit("mw-pki-rootCA.service")
        #  intermediateCA.succeed("check that myLaptop's key is useable")
        #'';
      }

      #(lib.makeScope pkgs.newScope (self'': {
      #  name = "mw-pki: client / full";
      #  nodes = {
      #    inherit
      #      myLaptop
      #      intermediateCA
      #      #server
      #      #client
      #      ;
      #  };
      #  testScript = let
      #    vlan = builtins.elemAt server.virtualisation.vlans 0;
      #    machinePos = builtins.unsafeGetAttrPos "server" self''.nodes;
      #    serverIP = "192.168.${vlan}.${machinePos}";
      #  in
      #    /*
      #    python
      #    */
      #    ''
      #      start_all()
      #      myLaptop.wait_for_unit("ssh-ca.service")
      #      intermediateCA.wait_for_unit("ssh-ca.service")
      #      server.wait_for_unit("ssh-ca.service")
      #      client.wait_for_unit("ssh-ca.service")
      #      # NOTE::IMPROVEMENT is there a way to pull the IP address in from
      #      # whichever part of nixpkgs processes the `virtualisation.vlans` option?
      #      client.succeed("ssh server -- echo 'works!'")
      #    '';
      #}))
    ];
    defaults = {
      imports = [
        self.nixosModules.testUser
      ];
      networking.firewall.enable = false;
      environment.systemPackages = [
        pkgs.socat
      ];

      documentation.enable = false;
      virtualisation = {
        useBootLoader = false;
        memorySize = 256; # MiB
        cores = 1;
        graphics = false;
        restrictNetwork = true;
      };
    };
  }
