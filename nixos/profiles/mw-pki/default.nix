{
  self,
  lib,
  ...
}: {
  # NOTE::CONTINUE I should consider not creating a new systemd service for
  # each of these, and instead enforce the rule that at least the root-ca and
  # intermediate-ca can't be used in the same config, perhaps by making
  # services.mw-pki an option of type attrset, and setting the merge rules to
  # throw an error if more than one of the two has `.enable = true`
  _module.args = {
    inherit self;
  };
  imports = [
    ./intermediate-ca.nix
    #./server.nix
    #./client.nix
  ];

  options.services.mw-pki = lib.mkOption {
    description = ''
      my smallstep-powered setup for distributing TLS certificates, as well as SSH certificates, which I use with sops-nix for distributing secrets
    '';
    example = lib.literalExpression ''{intermediateCA.enable = true; server.enable = true;}'';
    type = lib.types.attrsOf lib.types.optionDeclaration;
  };
}
