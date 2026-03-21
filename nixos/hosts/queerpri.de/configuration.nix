{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../profiles/git-host.nix
    ../../profiles/ssh-ca
  ];

  networking.hostName = "queerpri";
  networking.domain = "de";

  services.userborn.enable = true;
  virtualisation = let
    vmVariant = {
      virtualisation = {
        memorySize = 512;
        cores = 1;
        graphics = false;
      };
    };
  in {
    inherit vmVariant;
    vmVariantWithBootLoader = vmVariant;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "25.11";
}
