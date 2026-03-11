{
  pkgs,
  config,
  lib,
  ...
}: {
  boot.stage2Greeting =
    pkgs.callPackage ./ascii-cat-banner.nix {
      bannerLines = [
        config.system.nixos.distroName
        "Stage 2"
        ""
        "        meow"
      ];
      moveShortestDownBy = 1;
      interBannerArtPadding = 0;
    }
    # NOTE::WORKAROUND this is because stage-2.nix directly inserts this string into stage-2-init.sh
    |> (s: ''"${lib.escapeShellArg s}"'');
  #services.getty.greetingLine =
  #  pkgs.callPackage ./ascii-cat-banner.nix {
  #    catIndex = 1;
  #    bannerLines = [
  #      "Welcome to"
  #      config.system.nixos.distroName
  #      config.system.nixos.label
  #      ""
  #      ""
  #      ''(\m) - \l''
  #    ];
  #  }
  #  |> lib.escapeShellArg;
}
