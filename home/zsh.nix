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
      enableFishIntegration = true;
    };
    programs.dircolors = {
      enable = true;
      enableFishIntegration = true;
    };
    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.fish = {
      enable = true;
      plugins = [ ];
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
