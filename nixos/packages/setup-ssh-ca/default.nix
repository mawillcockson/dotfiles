{pkgs, ...}:
(pkgs.callPackage ./helpers/needs-pkgs.nix {}).writeNuApplication {
  name = "setup-ssh-ca.nu";
  runtimeInputs = [pkgs.openssh];
  text = builtins.readFile ./setup-ssh-ca.nu;
}
