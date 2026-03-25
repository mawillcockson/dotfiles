{
  pkgs,
  lib,
  ...
}: let
  helpers = import ./no-pkgs-needed.nix;
in {
  writeNuApplication = {
    /*
    The name of the script to write.

    Type: String
    */
    name,
    /*
    The nu script's text, not including a shebang.

    Type: String
    */
    text,
    /*
    Inputs to add to the nu script's `$PATH` at runtime.

    Type: [String|Derivation]
    */
    runtimeInputs ? [],
    /*
    Extra environment variables to set at runtime.

    Type: AttrSet
    */
    runtimeEnv ? null,
    /*
    `stdenv.mkDerivation`'s `meta` argument.

    Type: AttrSet
    */
    meta ? {},
    /*
    `stdenv.mkDerivation`'s `passthru` argument.

    Type: AttrSet
    */
    passthru ? {},
    /*
    The `checkPhase` to run. Defaults to `nu -c 'nu-check $target'`.

    The script path will be given as `$target` in the `checkPhase`.

    Type: String
    */
    checkPhase ? null,
    /*
    List of paths to add to NU_LIB_DIRS.

    Will be concatenated with `char record_sep`, as per `nu --help`

    Type: [String|Path|Derivation]
    */
    libDirs ? [],
    /*
    Start with no config file and no env file.

    Passes --no-config-file.

    Type: Bool
    */
    noConfigFile ? true,
    /*
    Disable reading and writing to command history.

    Passes --no-history.

    Type: Bool
    */
    noHistory ? true,
    /*
    Start with no standard library. This prevents `use std`.

    Passes --no-std-lib.

    Type: Bool
    */
    noStdLib ? false,
    /*
    Start with an alternate config file.

    Passes --config <path>.

    Type: String|Path
    */
    configFile ? null,
    /*
    Start with an alternate environment config file.

    Passes --env-config <path>.

    Type: String|Path
    */
    envFile ? null,
    /*
    Log level for diagnostic logs (error, warn, info, debug, trace). Off by default.

    This is the logging level for internal nushell commands and code. It does not influence `std/log`.

    Scripts can dynamically change the log level used by `std/log` by setting the `NU_LOG_LEVEL` variable.

    Consult the documentation for more information: https://www.nushell.sh/book/special_variables.html#env-nu-log-level

    Type: Null|String
    */
    nuLogLevel ? null,
    /*
    Extra arguments to pass to `stdenv.mkDerivation`.

    :::{.caution}
    Certain derivation attributes are used internally,
    overriding those could cause problems.
    :::

    Type: AttrSet
    */
    derivationArgs ? {},
    /*
    Whether to inherit the current `$PATH` in the script.

    Type: Bool
    */
    inheritPath ? true,
    /*
    The nu package to use.

    Type: Derivation
    */
    package ? pkgs.nushell,
  } @ args: let
    booleanFlags = {
      "--no-config-file" = noConfigFile;
      "--no-history" = noHistory;
      "--no-std-lib" = noStdLib;
    };
    pathFlags = {
      "--config" = configFile;
      "--env-config" = envFile;
      # not a path, but functionally the same
      "--log-level" = nuLogLevel;
    };
    record_sep = "";
    libDirsOpt = "--include-path=${builtins.concatStringsSep record_sep libDirs}";
    Path = map (p: p |> lib.getExe |> builtins.dirOf) runtimeInputs |> builtins.concatStringsSep ":";
    defaultRuntimeEnv =
      if builtins.isNull runtimeEnv
      then {}
      else runtimeEnv;
    runtimePath =
      Path
      + lib.optionalString (defaultRuntimeEnv |> builtins.hasAttr "PATH") (
        lib.warn
        "writeNuApplication was passed $PATH contents in `runtimeEnv`, and will append it to any `runtimeInputs`"
        (":" + defaultRuntimeEnv.PATH)
      );
    allEnv =
      defaultRuntimeEnv
      // {
        PATH = runtimePath;
      };
    scriptFile = pkgs.writeTextFile {
      name = "actual-${name}";
      inherit text;
    };
  in
    pkgs.writeTextFile {
      inherit
        name
        meta
        passthru
        derivationArgs
        ;
      executable = true;
      destination = "/bin/${name}";
      allowSubstitutes = true;
      preferLocalBuild = false;
      text =
        /*
        nu
        */
        ''
          #!${lib.getExe package}
          echo ${builtins.toJSON allEnv |> helpers.quoteNu} |
          from json |
          load-env
          exec ...([
            $nu.current-exe
            ${lib.concatMapAttrsStringSep "\n" (flag: value:
            if value
            then flag
            else "")
          booleanFlags}
            ${lib.concatMapAttrsStringSep "\n" (
              flag: value:
                if builtins.isNull value
                then ""
                else helpers.quoteNu "${flag}=${value}"
            )
            pathFlags}
          ${
            if builtins.length libDirs > 0
            then libDirsOpt + "\n"
            else ""
          }${scriptFile}
          ])
        '';

      checkPhase =
        if checkPhase == null
        then
          /*
          bash
          */
          ''
            runHook preCheck
            ${lib.getExe package} \
                --no-config-file \
                --no-history \
                --error-style plain \
                "$target"
            runHook postCheck
          ''
        else checkPhase;
    };
}
