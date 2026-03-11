{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = {nixpkgs, ...}: let
    nixosConfigurations."queerpri.de" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./systems/queerpri.de/configuration.nix
      ];
    };
    # from:
    # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf?permalink_comment_id=5167381#gistcomment-5167381
    apps = {
      default = apps.test;
      test = {
        type = "app";
        program = "${nixosConfigurations."queerpri.de".config.system.build.vm}/bin/run-${
          nixosConfigurations."queerpri.de".config.networking.hostName
        }-vm";
      };
    };
  in {
    inherit nixosConfigurations;
    apps.x86_64-linux = apps;
  };
}
