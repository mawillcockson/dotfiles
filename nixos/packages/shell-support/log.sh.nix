{
  pkgs,
  lib,
  ...
}:
# NOTE::DONE why didn't I use `pkgs.writeShellApplication` here,
# again? If it's because I wanted shellcheck to use `sh` instead of `bash`, I
# could've overridden just the checkPhase
# Explanation: it's because `pkgs.writeShellApplication` sets the `destination`
# attribute of `pkgs.writeTextFile` to a subdirectory, and I wanted this to be
# a single file, referencable by importing this package.
# It does mean I do miss out on some things, like a more complicated checkPhase
# definition, that doesn't run shellcheck on platforms that can't compile it.
pkgs.writeTextFile {
  name = "log.sh";
  executable = true;
  preferLocalBuild = false;
  allowSubstitutes = true;
  text = builtins.readFile ../../../debian/usr/local/share/sh/log.sh;
  checkPhase = ''
    runHook preCheck
    ${pkgs.stdenv.shellDryRun} "$target"
    ${lib.getExe pkgs.shellcheck-minimal} --shell=sh "$target"
    runHook postCheck
  '';
}
