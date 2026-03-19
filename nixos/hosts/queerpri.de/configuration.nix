{
  lib,
  pkgs,
  ...
}: let
  user = "test";
  vmVariant = {
    virtualisation = {
      memorySize = 512;
      cores = 1;
      graphics = false;
    };
    # inspired by:
    # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf
    users.groups.${user} = {};
    users.users.${user} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      password = user;
      group = user;
    };
    # Username of the account that will be automatically logged in at the
    # console. If unspecified, a login prompt is shown as usual.
    services.getty.autologinUser = user;

    # Whether users of the wheel group must provide a password to run commands
    # as super user via sudo.
    security.sudo.wheelNeedsPassword = false;
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../common
    ../../profiles/git-host.nix
    ../../profiles/ssh-ca
  ];

  # Only allow members of the wheel group to execute sudo by setting the
  # executable’s permissions accordingly. This prevents users that are not
  # members of wheel from exploiting vulnerabilities in sudo such as
  # CVE-2021-3156.
  security.sudo.execWheelOnly = true;

  networking.hostName = "queerpri";
  networking.domain = "de";

  services.userborn.enable = true;
  virtualisation.vmVariant = vmVariant;
  virtualisation.vmVariantWithBootLoader = vmVariant;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  system.stateVersion = "25.11";
}
