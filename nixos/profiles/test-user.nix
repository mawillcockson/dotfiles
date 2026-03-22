{
  config,
  lib,
  ...
}: let
  cfg = config.services.testUser;
in {
  options = {
    services.testUser = {
      description = "add a user account with a password that matches the username, and enable autologin with getty for that user";
      enable = lib.mkEnableOption "testUser";
      user = lib.mkOption {
        type = lib.types.passwdEntry lib.types.str;
        default = "test";
        example = ''"test"'';
      };
    };
  };
  config = lib.mkIf cfg.enable {
    # inspired by:
    # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf
    users.groups.${cfg.user} = lib.mkDefault {};
    users.users.${cfg.user} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      password = cfg.user;
      group = cfg.user;
    };
    # Username of the account that will be automatically logged in at the
    # console. If unspecified, a login prompt is shown as usual.
    services.getty.autologinUser = cfg.user;

    # Whether users of the wheel group must provide a password to run commands
    # as super user via sudo.
    security.sudo.wheelNeedsPassword = false;
  };
}
