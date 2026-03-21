{
  pkgs,
  lib,
  ...
}:
pkgs.testers.runNixOSTest {
  imports = [./loginAsTest.nix];

  defaults = {
    services.testUser = lib.mkDefault true;
    documentation.enable = lib.mkDefault false;
  };
}
