{pkgs,lib,nixos-lib ? import (lib.path.append pkgs.path "/nixos/lib"}: nixos-lib.runTest {
  hostPkgs = pkgs;
  defaults.documentation.enable = lib.mkDefault false;
  imports = [
