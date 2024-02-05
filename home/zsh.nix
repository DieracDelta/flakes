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
        directory.fish_style_pwd_dir_length = 1; # turn on fish directory truncation
        directory.truncation_length = 2; # number of directories not to truncate
      };
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      enableBashIntegration = true;
    };
    programs.dircolors = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };
    home.sessionVariables = { NIX_BUILD_SHELL = "fish"; };
    programs.fish = {
      enable = true;

      #programs.zsh.defaultKeymap = "vicmd";

      plugins = [];

      # aliases
      shellAliases = {
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gs = "git status";
        gsb = "git status -sb";

        ".." = "cd ..";
        bahs = "bash";
        build_root = "sudo nixos-rebuild switch";
        burn = "pkill -9";
        cat = "bat";
        cdh = "cd $HOME";
        l = "ls -lF --time-style=long-iso --grid --icons";
        la = "l -a";
        list_gens = "nix-env -p /nix/var/nix/profiles/system --list-generations";
        ll = "ls -l";
        ls = "eza -h --git --color=auto --group-directories-first -s extension";
        nd = "nix develop -c fish ";
        sl = "ls";

      };
      # keys.sh contains a bunch of my keys
      interactiveShellInit = builtins.readFile ./zshrc;
    };
  };
}
