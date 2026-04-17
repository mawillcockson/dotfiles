{lib, ...}: {
  allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      # add specific unfree packages that should be allowed, here
    ];
}
