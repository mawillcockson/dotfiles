{
  pkgs ? let
    json = builtins.readFile ../../../flake.lock |> builtins.fromJSON;
    inherit
      (json.nodes.nixpkgs.locked)
      type
      owner
      repo
      rev
      ;
    nixpkgs = builtins.fetchTarball "https://${type}.com/${owner}/${repo}/archive/master.tar.gz?rev=${rev}";
  in
    import nixpkgs {
      config = {};
      overlays = [];
    },
  lib ? pkgs.lib,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "autologin as test";
  nodes.machine = {...}:
    pkgs.callPackage ../configuration.nix {}
    |> builtins.getAttr "virtualisation"
    |> builtins.getAttr "vmVariant"
    |> (
      v:
        v
        // {
          imports = [../configuration.nix];
          environment.systemPackages = [pkgs.getent];

          fileSystems."/" = {
            device = "/dev/disk/by-partlabel/root";
            fsType = "ext4";
          };

          fileSystems."/boot/efi" = {
            device = "/dev/disk/by-partlabel/ESP";
            fsType = "vfat";
            options = [
              "fmask=0022"
              "dmask=0022"
            ];
          };

          swapDevices = null;
        }
    );
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
