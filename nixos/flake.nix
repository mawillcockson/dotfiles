{
  description = "personal nix stuff";

  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      flake-parts.url = "github:hercules-ci/flake-parts";
      sops-nix.url = "github:Mic92/sops-nix";
      sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    }
    #// (
    #  if (builtins.pathExists ../../secrets)
    #  then {
    #    secrets = {
    #      # very fake flakeref
    #      url = "file://${builtins.toString ../../secrets}";
    #      inputs.nixpkgs.follows = "nixpkgs";
    #    };
    #  }
    #  else {
    #    secrets = {
    #      # very fake flakeref
    #      url = "forgejo:git@queerpri.de/secrets";
    #      inputs.nixpkgs.follows = "nixpkgs";
    #    };
    #  }
    #)
    ;
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    sops-nix,
    ...
  }: let
    helpers = import ./helpers.nix;
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
        packages = {
          default = self'.packages.step-ca-init;
          inherit (pkgs) step-ca step-cli;
          step-ca-init = pkgs.writeShellApplication {
            name = "step-ca-init.sh";
            runtimeInputs = [
              pkgs.step-ca
              pkgs.step-cli
            ];
            text = builtins.readFile ./profiles/ssh-ca/step-ca-init.sh;
          };

          # NOTE::QUESTION I was silly, and this isn't necessary in this case,
          # but I'm still curious why it didn't work, as I may want to make a
          # wrapper script in the future, that has only specific programs
          # available to it. Kind of a mkShellNoCC, but it directly calls a
          # particular program
          #step-wrapper = pkgs.stdenvNoCC.mkDerivation {
          #  name = "step-wrapper";
          #  # I want to know why the below fails on the makeWrapper line
          #  #nativeBuildInputs = [
          #  #  pkgs.makeWrapper
          #  #  pkgs.breakpointHook
          #  #  pkgs.step-cli
          #  #];
          #  #buildInputs = [
          #  #  pkgs.step-cli
          #  #  pkgs.step-ca
          #  #];
          #  #builder = builtins.toFile "builder.sh" ''
          #  #  mkdir -p "$out/bin"
          #  #  cp -v "$(command -v step)" "$out/bin/"
          #  #  makeWrapper "$out/bin/step"
          #  #'';
          #  nativeBuildInputs = [pkgs.step-cli];
          #  buildInputs = [
          #    pkgs.step-ca
          #    pkgs.step-cli
          #  ];
          #  builder = builtins.toFile "builder.sh" ''
          #    mkdir -p "$out/bin"
          #    cp -v "$(command -v step)" "$out/bin/"
          #  '';
          #  meta.description = "wrapper for step-cli that includes step-ca";
          #};
        };

        # from:
        # https://gist.github.com/FlakM/0535b8aa7efec56906c5ab5e32580adf?permalink_comment_id=5167381#gistcomment-5167381
        apps = {
          default = self'.apps."queerpri.de-vm";
          "queerpri.de-vm" = {
            type = "app";
            program = let
              configuration = self.nixosConfigurations."queerpri.de".extendModules {
                modules = [
                  self.nixosModules.testUser
                ];
              };
              scriptsDir = configuration.config.system.build.vm;
              inherit (configuration.config.networking) hostName;
            in "${scriptsDir}/bin/run-${hostName}-vm";
            meta.description = "run the queerpri.de config's vm script (config.system.build.vm)";
          };
          #"queerpri.de-vmWithBootLoader" = {
          #  type = "app";
          #  program = let
          #    scriptsDir = queerpri.de.config.system.build.vmWithBootLoader;
          #    inherit (queerpri.de.config.networking) hostName;
          #  in "${scriptsDir}/bin/run-${hostName}-vmWithBootLoader";
          #  meta.description = "run the queerpri.de config's vm \"with a boot loader\" script (config.system.built.vmWithBootLoader)";
          #};
          step = {
            type = "app";
            program = pkgs.lib.getExe pkgs.step-cli;
            meta.description = pkgs.step-cli.meta.description;
          };
          step-ca = {
            type = "app";
            program = pkgs.lib.getExe pkgs.step-ca;
            meta.description = pkgs.step-ca.meta.description;
          };
          nixos-generate-config = {
            type = "app";
            program = "${pkgs.nixos-install-tools.outPath}/bin/nixos-generate-config";
            meta.description = pkgs.nixos-install-tools.meta.description;
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
          default = self'.devShells.noCC;
          noCC = pkgs.mkShellNoCC options;
          cc = pkgs.mkShell options;
          "queerpri.de" = self'.devShells.noCC.overrideAttrs (
            finalAttrs: previousAttrs: {
              nativeBuildInputs =
                previousAttrs.nativeBuildInputs
                ++ self.nixosConfigurations."queerpri.de".config.environment.systemPackages
                ++ [pkgs.step-cli];
            }
          );
        };
        checks =
          {
            # prefix test names with package they're from
            default = self'.checks."queerpri.de-loginAsTest";
          }
          // (
            pkgs.callPackage ./hosts/queerpri.de/tests {}
            |> (
              # necessary, because `pkgs.callPackage` adds these functions, and I don't need them
              s:
                removeAttrs s [
                  "override"
                  "overrideDerivation"
                ]
            )
            |> helpers.renameAttrs (name: value: {"queerpri.de-${name}" = value;})
          );
      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        nixosConfigurations = {
          default = self.nixosConfigurations."queerpri.de";
          "queerpri.de" = nixpkgs.lib.nixosSystem {
            modules = [
              sops-nix.nixosModules.sops
              self.nixosModules."queerpri.de"
            ];
            system = "x86_64-linux";
          };
        };
        nixosModules = {
          "queerpri.de" = ./hosts/queerpri.de/configuration.nix;
          testUser = ./profiles/test-user.nix;
        };
      };
    };
}
