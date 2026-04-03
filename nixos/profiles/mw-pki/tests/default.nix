{
  self,
  lib,
  pkgs,
  ...
}: let
  myLaptop = {...}: {
    virtualisation.vlans = [1];
    services.mw-pki.rootCA = {
      enable = true;
      insecure = true;
    };
    imports = [self.nixosModules.mw-pki];
  };
  # make it clear how I want to run this
  rootCA = myLaptop;
  intermediateCA = {...}: {
    virtualisation.vlans = [
      1
      2
    ];
    services.mw-pki.intermediateCA.enable = true;
    imports = [self.nixosModules.mw-pki];
  };
  server = {...}: {
    virtualisation.vlans = [2];
    services.mw-pki.server.enable = true;
    imports = [self.nixosModules.mw-pki];
  };
  client = {...}: {
    virtualisation.vlans = [2];
    services.mw-pki.client.enable = true;
    imports = [self.nixosModules.mw-pki];
  };
in
  pkgs.testers.runNixOSTest {
    imports = [
      {
        name = "mw-pki tests";
        nodes = {inherit rootCA;};
        testScript =
          /*
          python
          */
          ''
            myLaptop.start(allow_reboot=True)
            myLaptop.wait_for_unit("ssh-ca.service")
          '';
      }
      {
        name = "mw-pki: intermediate CA";
        nodes = {inherit myLaptop intermediateCA;};
        testScript =
          /*
          python
          */
          ''
            intermediateCA.start(allow_reboot=True)
            intermediateCA.wait_for_unit("ssh-ca.service")
          '';
      }

      (lib.makeScope pkgs.newScope (self'': {
        name = "mw-pki: client / full";
        nodes = {
          inherit
            myLaptop
            intermediateCA
            server
            client
            ;
        };
        testScript = let
          vlan = builtins.elemAt server.virtualisation.vlans 0;
          machinePos = builtins.unsafeGetAttrPos "server" self''.nodes;
          serverIP = "192.168.${vlan}.${machinePos}";
        in
          /*
          python
          */
          ''
            start_all()
            myLaptop.wait_for_unit("ssh-ca.service")
            intermediateCA.wait_for_unit("ssh-ca.service")
            server.wait_for_unit("ssh-ca.service")
            client.wait_for_unit("ssh-ca.service")
            # NOTE::IMPROVEMENT is there a way to pull the IP address in from
            # whichever part of nixpkgs processes the `virtualisation.vlans` option?
            client.succeed("ssh ${serverIP} -- echo 'works!'")
          '';
      }))
    ];
    defaults = {
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
