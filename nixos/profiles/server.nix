{pkgs, ...}: {
  environment.etc."tmux.conf".source = ../../dot_config/tmux/tmux.conf;

  environment.systemPackages = [
    pkgs.neovim
    pkgs.nushell
    pkgs.tmux
  ];
}
