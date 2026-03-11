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
    # Whether users of the wheel group must provide a password to run commands
    # as super user via sudo.
    security.sudo.wheelNeedsPassword = false;
  };
in {
  imports = [
    ../common
    ../../profiles/git-host.nix
  ];

  #boot.sys

  # Only allow members of the wheel group to execute sudo by setting the
  # executable’s permissions accordingly. This prevents users that are not
  # members of wheel from exploiting vulnerabilities in sudo such as
  # CVE-2021-3156.
  security.sudo.execWheelOnly = true;

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
