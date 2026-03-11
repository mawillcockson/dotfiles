{
  config,
  nixpkgs ? builtins.findFile [
    {
      prefix = "nixpkgs";
      path = "channel:nixos-25.11-small";
    }
  ] "nixpkgs",
  ...
}: let
# use currently "recommended" way to import nixpkgs
# https://github.com/NixOS/nixpkgs/issues/339635#issue-2506369834
  pkgs = import "${nixpkgs}/pkgs/top-level" {
    config = {};
    overlays = [];
    localSystem.system = builtins.currentSystem;
  };
in
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix"

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
  ];
  environment.systemPackages = let
    p = pkgs;
  in [
    p.neovim
    p.keepass
    p.xorg.xinit
    p.xorg.xorgserver
    p.alacritty
    p.tmux
    p.curl
    p.cacert
    p.gnupg
    p.pinentry-tty
    p.dash
    p.cryptsetup
    p.coreutils
    p.sudo
    p.util-linux
  ];

  services.xserver.desktopManager.xfce.enable = true;
  services.displayManager.defaultSession = "xfce";
}
