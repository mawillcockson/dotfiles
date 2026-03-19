{
  pkgs,
  lib,
  ...
}:
pkgs.testers.nixOSTest {
  imports = [(pkgs.callPackage ./loginAsTest.nix {})];
  defaults.documentation.enable = lib.mkDefault false;
}
