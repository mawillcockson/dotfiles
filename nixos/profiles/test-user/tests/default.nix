{pkgs, ...}:
pkgs.testers.runNixOSTest {
  imports = [
    {
      name = ''autologin as user "test"'';
      nodes.machine = {...}: {
        imports = [./test-user.nix];
      };
      testScript = ''
        machine.start(allow_reboot=True)
        machine.wait_for_unit("multi-user.target")
        machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")
        machine.succeed("getent passwd test")
        machine.wait_until_succeeds("pgrep -u test bash")
        machine.send_chars("id -un\n")
        machine.wait_until_tty_matches("1", "test\n")
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
