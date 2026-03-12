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
  }: let
    nixosConfigurations = (
      system: {
        "queerpri.de" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./systems/queerpri.de/configuration.nix
          ];
        };
      }
    );
  in
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

        packages = {
          default = pkgs.hello;
          step-ca-init =
            builtins.readFile ./profiles/ssh-ca/step-ca-init.sh
            |> pkgs.runCommand "step-ca-init.sh" {
              nativeBuildInputs = [
                pkgs.step-ca
                pkgs.step-cli
              ];
            };
        };

        # from:
        # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf?permalink_comment_id=5167381#gistcomment-5167381
        apps = {
          default = self'.apps."queerpri.de-vm";
          "queerpri.de-vm" = {
            type = "app";
            program = "${(nixosConfigurations system)."queerpri.de".config.system.build.vm}/bin/run-${
              (nixosConfigurations system)."queerpri.de".config.networking.hostName
            }-vm";
          };
          "queerpri.de-vmWithBootLoader" = {
            type = "app";
            program = "${
              (nixosConfigurations system)."queerpri.de".config.system.build.vmWithBootLoader
            }/bin/run-${
              (nixosConfigurations system)."queerpri.de".config.networking.hostName
            }-vmWithBootLoader";
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
          "queerpri.de" = self'.devShells.default.overrideAttrs (
            finalAttrs: previousAttrs: {
              nativeBuildInputs =
                previousAttrs.nativeBuildInputs
                ++ (nixosConfigurations system)."queerpri.de".config.environment.systemPackages
                ++ [pkgs.step-cli];
            }
          );
        };
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        nixosConfigurations = nixosConfigurations "x86_64-linux";
      };
    };
}
