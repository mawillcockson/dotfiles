{
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
