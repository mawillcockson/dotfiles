{
  pkgs,
  config,
  lib,
  ...
}: {
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 15;
    # allow editing the kernel commandline? Recommended to be set to `false`,
    # to prevent someone from getting root access on boot
    editor = true;
    memtest86.enable = true;
    netbootxyz.enable = true;
  };
  boot.loader.timeout = 3;
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


  # Only allow members of the wheel group to execute sudo by setting the
  # executable’s permissions accordingly. This prevents users that are not
  # members of wheel from exploiting vulnerabilities in sudo such as
  # CVE-2021-3156.
  security.sudo.execWheelOnly = true;

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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
