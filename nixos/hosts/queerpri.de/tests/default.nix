{
  pkgs,
  lib,
  ...
}:
pkgs.testers.runNixOSTest {
  imports = [];

  defaults = {
    documentation.enable = lib.mkDefault false;
  };
}
