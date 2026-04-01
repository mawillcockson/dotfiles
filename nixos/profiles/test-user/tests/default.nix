{
  self,
  pkgs,
  ...
}: let
  cfg =
    self.inputs.nixpkgs.lib.nixosSystem {
      modules = [self.nixosModules.testUser];
      system = pkgs.stdenv.hostPlatform.system;
    }
    |> builtins.getAttr "config"
    |> builtins.getAttr "services"
    |> builtins.getAttr "testUser";
in
  pkgs.testers.runNixOSTest {
    imports = [
      {
        name = ''autologin as user "test"'';
        nodes.machine = {...}: {
          imports = [self.nixosModules.testUser];
        };
        testScript =
          /*
          python
          */
          ''
            machine.start(allow_reboot=True)
            machine.wait_for_unit("multi-user.target")
            machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
            machine.succeed("getent passwd ${cfg.user}")
            machine.wait_until_succeeds("pgrep -u test bash")
            # NOTE::IMPROVE there's probably a better way to check if the
            # default console can have commands entered at it, when testUser is
            # enabled, because agetty is set to login automatically with the
            # test user
            machine.send_chars("unset -v PS1\n")
            machine.send_chars("id -un\n")
            machine.wait_until_tty_matches("1", r"id -un\s+${cfg.user}\s*$")
          '';
      }
    ];
    defaults = {
      services.testUser.enable = true;
      documentation.enable = false;
      virtualisation = {
        useBootLoader = false;
        memorySize = 512; # MiB
        cores = 1;
        graphics = false;
        restrictNetwork = true;
      };
    };
  }
