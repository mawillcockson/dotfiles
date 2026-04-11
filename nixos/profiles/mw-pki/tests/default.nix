{
  self,
  lib,
  pkgs,
  ...
}: let
  rootCA = {...}: {
    virtualisation.vlans = [1];
    services.mw-pki.rootCA = {
      enable = true;
      insecure = true;
    };
    imports = [../root-ca.nix];
  };
  # make it clear how I want to run this
  myLaptop = rootCA;
  intermediateCA = {...}: {
    virtualisation.vlans = [
      1
      2
    ];
    #imports = [self.nixosModules.mw-pki];
    #services.mw-pki.intermediateCA.enable = true;
    environment.systemPackages = [
      pkgs.step-ca
      pkgs.step-cli
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
            intermediateCA.start()
            myLaptop.wait_for_unit("mw-pki-rootCA.service")
            intermediateCA.succeed(
                "sudo -u test -- step 
          '';
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
