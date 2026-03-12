{
  config,
  lib,
  pkgs,
  ...
}: let
  vmVariant = {
    services.step-ca = "/var/lib/step-ca/config/ca.json";
    #NOTE: jq -> db.dataSource = "/var/lib/step-ca/db";
    # this isn't allowed to be a path in the nix store, probably to prevent a
    # secret being accidentally imported into the nix store where it would
    # likely be world-readable (thanks maintainers, for looking out for me!).
    # But I don't mind that, for the purposes of testing.
    #intermediatePasswordFile = "${init}/secrets/password.txt";
  };
in {
  imports = [../server.nix];

  services.step-ca = {
    enable = true;
    openFirewall = true;
    address = "127.0.0.1";
    port = 52086;
  };

  environment.systemPackages = [pkgs.step-ca];

  #virtualisation.vmVariant = vmVariant;
  #virtualisation.vmVariantWithBootLoader = vmVariant;

  # I think services.step-ca.enable pulls in the necessary packages already
  #environment = {
  #  systemPackages = [pkgs.step-ca pkgs.step-cli];
  #};
}
