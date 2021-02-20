{ config, pkgs, lib, inputs, ... }:
let cfg = config.profiles.zsh;
in
{
  options.profiles.zsh.enable =
    lib.mkOption {
      description = "Enable custom vim configuration.";
      type = with lib.types; bool;
      default = true;
    };
  config = lib.mkIf cfg.enable {
    programs.autojump = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.starship = {
      settings = {
        add_newline = false;
      };
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };
    programs.dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    home.sessionVariables = {
      NIX_BUILD_SHELL="zsh";
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableAutosuggestions = true;
      autocd = true;
      #programs.zsh.defaultKeymap = "vicmd";
      history.extended = true;
      history.ignoreDups = true;
      history.path = ".zsh_history";
      history.save = 10000000;
      history.share = true;
      history.size = 10000000;

      plugins = [
        pkgs.nix-fast-syntax-highlighting
        pkgs.nix-zsh-shell-integration
      ];

      # aliases
      shellAliases = {
        nd = "nix develop -c zsh";
        l = "ls -lF --time-style=long-iso --grid --icons";
        la = "l -a";
        ls = "exa -h --git --color=auto --group-directories-first -s extension";
        lstree = "ls --tree";
        tree = "lstree";
        cat = "bat";

        nix-repl = "export __NIXOS_SET_ENVIRONMENT_DONE='' && nix repl $(source /etc/profile && echo $NIX_PATH | perl -pe 's|.*(/nix/store/.*-source/repl.nix).*|\\1|')";
        "ll" = "ls -l";
        ".." = "cd ..";
        "query" =
          "nix-store --query --requisites /run/current-system | cut -d- -f2- | sort -u";
        "hb" = "home-builder switch";
        "build_root" = "sudo nixos-rebuild switch";
        "query_vim_pkgs" = "nix-env -f '<nixpkgs>' -qaP -A vimPlugins";
        "gen_wal" =
          "wal --backend wal --iterative -i $HOME/Downloads/wallpapers/Future/";
        "delete_gens" =
          "nix-env -p /nix/var/nix/profiles/system --delete-generations old";
        "list_gens" = "nix-env -p /nix/var/nix/profiles/system --list-generations";
        "spawn_docker" = ''
          docker run --rm -it -m="12G" --memory-swap="0G" --mount type=bind,src=$HOME/work,dst=/work bap:latest /bin/bash'';
        "start_nix_shell" =
          "nix-shell --pure -E 'with import<nixpkgs> {}; callPackage ./. {}";
        "alacritty_x" = "env WINIT_UNIX_BACKEND=x11 alacritty & disown && exit";
        "nu" =
          "sudo nixos-rebuild switch --flake $HOME/.config/nixkpkgs/configuration.nix";
        # "sudo NIXOS_CONFIG=$HOME/.config/nixpkgs/configuration.nix nixos-rebuild switch";
        # run lorri
        "rl" = "lorri init && direnv allow";
        "cdh" = "cd $HOME";
        "emacs_headless" = "emacs -nw";
        "re" = "systemctl --user restart emacs.service";
        "scu" = "systemctl --user";
        # "zathura" = "zathura_pwyal.sh";
        "sl" = "ls";
        "bahs" = "bash";
        "nixman" =
          "manix '' | grep '^# ' | sed 's/^# (.*) (.*/1/;s/ (.*//;s/^# //' | sed 's/</\\\\</g' | sed 's/>/\\\\>/g'| fzf --ansi --preview=\"manix '{}' | sed 's/type: /> type: /g' | bat -l Markdown --color=always --plain\"";

      };
      # keys.sh contains a bunch of my keys
      initExtra = builtins.readFile ./zshrc;
    };
  };
}
