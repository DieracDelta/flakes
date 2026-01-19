# Minimal home-manager config for servers (ARM OCI, etc.)
# Only includes: fish, atuin, zoxide, tmux, git
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./fish.nix
    ./zoxide.nix
    ./tmux.nix
  ];

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.stateVersion = "25.11";

  # fish.nix has a profile option - enable it
  profiles.zsh.enable = true;

  # Atuin - shell history sync
  programs.atuin.enable = true;
  programs.atuin.enableFishIntegration = true;

  # Git - basic config
  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin@restivo.me";
    lfs.enable = true;
  };
}
