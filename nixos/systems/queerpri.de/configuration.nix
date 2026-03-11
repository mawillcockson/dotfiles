{
  lib,
  pkgs,
  ...
}: let
  vmVariant = {
    virtualisation = {
      memorySize = 512;
      cores = 1;
      graphics = false;
    };
  };
in {
  imports = [
    ../common
    ../../profiles/git-host.nix
  ];

  #boot.sys

  networking.hostName = "queerpri";
  networking.domain = "de";

  services.userborn.enable = true;
  users.groups.admin = {};
  users.users = {
    admin = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      password = "admin";
      group = "admin";
    };
  };

  virtualisation.vmVariant = vmVariant;
  virtualisation.vmVariantWithBootLoader = vmVariant;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "25.11";
}
