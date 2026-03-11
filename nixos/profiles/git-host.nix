{
  config,
  lib,
  pkgs,
  ...
}: let
  git-shell = "${pkgs.gitMinimal}/bin/git-shell";
in {
  imports = [
    ./server.nix
  ];

  environment = {
    systemPackages = [pkgs.gitMinimal];
    shells = [git-shell];
  };

  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    home = "/home/git";
    createHome = true;
    description = "where git@example.com logs into";
    group = "git";
    # NOTE:DONE add the shell to /etc/shells
    # NOTE: and add a symlink at /usr/bin/git-shell
    shell = git-shell;
    # this should disable password login for this account
    initialHashedPassword = null;
  };
  # NOTE: create custom authorized_keys file and authorized_principals files, specifically for this configuration module, and add those files to the general sshd config
}
