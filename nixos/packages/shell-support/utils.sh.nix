{
  pkgs,
  lib,
  ...
}:
# NOTE::IMPROVEMENT why didn't I use `pkgs.writeShellApplication` here,
# again? If it's because I wanted shellcheck to use `sh` instead of `bash`, I
# could've overridden just the checkPhase
pkgs.writeTextFile {
  name = "utils.sh";
  executable = true;
  preferLocalBuild = false;
  allowSubstitutes = true;
  text = builtins.readFile ../../../debian/usr/local/share/sh/utils.sh;
  checkPhase = ''
    runHook preCheck
    ${pkgs.stdenv.shellDryRun} "$target"
    ${lib.getExe pkgs.shellcheck-minimal} --shell=sh "$target"
    runHook postCheck
  '';
}
