{
  self,
  lib,
  pkgs,
  ...
}: let
  myLaptop = {...}: {
    virtualisation.vlans = [1];
    services.mw-pki.root-ca = {
      enable = true;
      insecure = true;
    };
    imports = [self.nixosModules.mw-pki];
  };
  intermediateCa = {...}: {
    virtualisation.vlans = [
      1
      2
    ];
    services.mw-pki.intermediate-ca.enable = true;
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
        nodes = {inherit myLaptop;};
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
        nodes = {inherit myLaptop intermediateCa;};
        testScript =
          /*
          python
          */
          ''
            intermediateCa.start(allow_reboot=True)
            intermediateCa.wait_for_unit("ssh-ca.service")
          '';
      }

      (lib.makeScope pkgs.newScope (self'': {
        name = "mw-pki: client / full";
        nodes = {
          inherit
            myLaptop
            intermediateCa
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
            intermediateCa.wait_for_unit("ssh-ca.service")
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
