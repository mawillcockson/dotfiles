{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [./server.nix];

  services.step-ca = {
    enable = true;
    openFirewall = true;
    address = "127.0.0.1";
    port = 52086;
  };

  environment.systemPackages = [pkgs.step-ca];

  virtualisation.vmVariant = {
    services.step-ca = let
      init = pkgs.callPackage ../../packages/test-step-ca-init.nix {};
    in {
      settings = builtins.fromJSON "${init}/config/ca.json";
      intermediatePasswordFile = "${init}/secrets/password.txt";
    };
  };

  # I think services.step-ca.enable pulls in the necessary packages already
  #environment = {
  #  systemPackages = [pkgs.step-ca pkgs.step-cli];
  #};
}
