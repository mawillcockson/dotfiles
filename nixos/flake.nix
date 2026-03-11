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

        # from:
        # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf?permalink_comment_id=5167381#gistcomment-5167381
        apps = {
          default = self'.apps.test;
          test = {
            type = "app";
            program = "${config.nixosConfigurations."queerpri.de".config.system.build.vm}/bin/run-${
              config.nixosConfigurations."queerpri.de".config.networking.hostName
            }-vm";
          };
        };
        devShells = let
          options = {
            packages = [
              pkgs.atuin
              pkgs.starship
              pkgs.blesh
            ];
            shellHook = ''
              [[ $- == *i* ]] && source ${pkgs.blesh}/share/blesh/ble.sh --attach=none
              eval "$("${pkgs.atuin}/bin/atuin" init bash)"
              eval "$("${pkgs.starship}/bin/starship" init bash)"
              [[ ! ''${BLE_VERSION-} ]] || ble-attach
            '';
          };
        in {
          default = pkgs.mkShellNoCC options;
          cc = pkgs.mkShell options;
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        nixosConfigurations = {
          "queerpri.de" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./systems/queerpri.de/configuration.nix
            ];
          };
        };
      };
    };
}
