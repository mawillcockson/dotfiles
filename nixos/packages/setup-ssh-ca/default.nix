{pkgs, ...}: builtins.readFile ./setup-ssh-ca.nu |> pkgs.writers.writeNuBin "setup-ssh-ca.nu"
