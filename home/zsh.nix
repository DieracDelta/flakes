{ config, pkgs, lib, inputs, ... }:
let
  cfg = config.profiles.zsh;
in
{
  options.profiles.zsh.enable = lib.mkOption {
    description = "Enable custom vim configuration.";
    type = with lib.types; bool;
    default = true;
  };
  config = lib.mkIf cfg.enable {
    programs.starship = {
      settings = {
        add_newline = false;
        git_branch.disabled = true;
      };
      enable = true;
      enableBashIntegration = true;
    };
    programs.dircolors = {
      enable = true;
    };
    programs.fzf = {
      enable = true;
    };
  };
}
