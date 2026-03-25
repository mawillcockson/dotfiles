let
  max = a: b:
    if a > b
    then a
    else b;
  quoteBefore = "^.*('#+).*$";
  quoteAfter = "^.*(#+').*$";
  countHash = regex: string:
    builtins.match regex string
    # the regex will include an extra character (the single quote), and all the
    # rest will be what we want, so it doesn't really matter which character we
    # remove, as long as we remove one of them
    |> builtins.substring 1 (-1)
    |> builtins.stringLength
    |> (i: i / 2);
  countHashBeforeQuote = countHash quoteBefore;
  countHashAfterQuote = countHash quoteAfter;
  repeat = elem: builtins.genList (_: elem);
  stringRepeat = string: length': repeat string length' |> builtins.concatStringsSep "";
  quoteNu = s:
    if (builtins.match ".*#.*" s |> builtins.isNull)
    then "r#'${s}'#"
    else let
      hashCount = max (countHashBeforeQuote s) (countHashAfterQuote s);
      guardHashes = stringRepeat "#" (hashCount + 1);
    in "r${guardHashes}'${s}'${guardHashes}";
in {
  inherit
    max
    repeat
    stringRepeat
    quoteNu
    ;
  renameAttrs = (
    # renameFunction :: name: value: { newAttrName = newValue; }
    renameFunction: attrs:
      builtins.attrNames attrs
      |> builtins.map (name: {
        "${name}" = builtins.getAttr name attrs;
      })
      |> builtins.map (
        attr: let
          oldName = builtins.attrNames attr |> builtins.head;
          oldValue = builtins.getAttr oldName attr;
          new = renameFunction oldName oldValue;
          newName = let
            newAttrNames = builtins.attrNames new;
          in
            (
              if builtins.length newAttrNames > 1
              then
                builtins.warn (builtins.traceVerbose newAttrNames ''
                  renameFunction expected to return an attribute set with only one name, but got many (use --trace-verbose to see)
                  picking the first one
                '')
                newAttrNames
              else newAttrNames
            )
            |> builtins.head;
          newValue = builtins.getAttr newName new;
        in {
          name = newName;
          value = newValue;
        }
      )
      |> builtins.listToAttrs
  );
  # the nixos modules system doesn't like these attributes, or they're seen as
  # flakes options, and I like using callPackage
  removeCallPackageAttrs = attrs:
    removeAttrs attrs [
      "override"
      "overrideDerivation"
    ];
}
