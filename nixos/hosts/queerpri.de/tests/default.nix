{
  pkgs,
  lib,
  ...
}: {
  loginAsTest =
    pkgs.callPackage ./loginAsTest.nix {}
    |> (
      # necessary, because `pkgs.callPackage` adds these functions, and `runTest` via `runNixosTest` complains about them
      s:
        removeAttrs s [
          "override"
          "overrideDerivation"
        ]
    )
    |> (v: v // {defaults.documentation.enable = lib.mkDefault false;})
    |> pkgs.testers.runNixOSTest;
}
