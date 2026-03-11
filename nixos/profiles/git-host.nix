{
  config,
  lib,
  pkgs,
  ...
}: let
  a = 1;
in {
  environment.systemPackages = [pkgs.gitMinimal];
  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    createHome = true;
    description = "where git@example.com logs into";
    group = "git";
    # NOTE: add the shell to /etc/shells and add a symlink at /usr/bin/git-shell
    #shell = "${pkgs.gitMinimal}/bin/git-shell";
    initialHashedPassword = null;
  };
  # create custom authorized_keys file and authorized_principals files, specifically for this configuration module, and add those files to the general sshd config
}
