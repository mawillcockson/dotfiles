{self, ...}: {
  _module.args = {
    inherit self;
  };
  imports = [
    ./root-ca.nix
    ./intermediate-ca.nix
    ./server.nix
    ./client.nix
  ];
}
