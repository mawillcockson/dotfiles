{
  description = "personal nix stuff";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs @ {
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        # To import an internal flake module: ./other.nix
        # To import an external flake module:
        #   1. Add foo to inputs
        #   2. Add foo as a parameter to the outputs function
        #   3. Add here: foo.flakeModule
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        # I don't use these
        #"aarch64-darwin"
        #"x86_64-darwin"
      ];
      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        #packages.default = pkgs.hello;

        nixosConfigurations."queerpri.de" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./systems/queerpri.de/configuration.nix
          ];
        };
        # from:
        # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf?permalink_comment_id=5167381#gistcomment-5167381
        apps."${system}" = {
          default = self'.apps.test;
          test = {
            type = "app";
            program = "${self'.nixosConfigurations."queerpri.de".config.system.build.vm}/bin/run-${
              self'.nixosConfigurations."queerpri.de".config.networking.hostName
            }-vm";
          };
        };

        devShells."${system}" = let
          packages = [];
        in {
          default = pkgs.mkShellNoCC {inherit packages;};
          cc = pkgs.mkShell {inherit packages;};
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
      };
    };
}
