{
  config,
  lib,
  user ? "test",
  ...
}: {
  options = {
    services.testUser = {
      enable = lib.mkEnableOption "testUser";
    };
  };
  config = lib.mkIf config.services.testUser.enable {
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
}
