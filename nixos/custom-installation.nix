{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.user = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    initialHashedPassword = "$2b$05$CrJYEHn0tdSI6DVUZpLgWuYWP.9MzLk.Q8O0evt4bbmN6vpxG15be";
  };
  environment.systemPackages = [
    pkgs.neovim
    pkgs.sl
  ];

  documentation.man.enable = false;
  documentation.doc.enable = false;

  isoImage.efiSplashImage = pkgs.fetchurl {
    url = "https://willcockson.family/w/works.png";
    hash = "sha512-iqnLEfFor1aEN29s04MWAxsQ+m6bMl/AfV65+GKJU5JuruEfpqptomJ2ZozhlPYWKfIopGnl71kSitWViIeOQQ==";
  };

  system.stateVersion = "25.11";
}
