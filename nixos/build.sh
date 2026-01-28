#!/usr/bin/env nix-shell
#! nix-shell -i dash
#! nix-shell -p dash nix
#! nix-shell -I nixpkgs=channel:nixos-25.11-small
nix-build '<nixpkgs/nixos>' \
    -A config.system.build.isoImage \
    -I nixos-config=gpg_update.nix \
    -I nixpkgs=channel:nixos-25.11-small
