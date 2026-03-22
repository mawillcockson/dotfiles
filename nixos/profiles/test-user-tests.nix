{
  name = ''autologin as user "test"'';
  nodes.machine = {...}: {
    imports = [../configuration.nix];
    documentation.enable = false;
    virtualisation.graphics = false;
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
