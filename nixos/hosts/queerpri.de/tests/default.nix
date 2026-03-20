{
  pkgs,
  lib,
  ...
}: {
  loginAsTest =
    pkgs.callPackage ./loginAsTest.nix {}
    // {defaults.documentation.enable = lib.mkDefault false;}
    |> pkgs.testers.runNixOSTest;
}
