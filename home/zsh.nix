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
    home.sessionVariables = { NIX_BUILD_SHELL = "zsh"; };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      enableAutosuggestions = true;
      autocd = true;

      #programs.zsh.defaultKeymap = "vicmd";
      history.extended = true;
      history.ignoreDups = true;
      history.save = 10000000;
      history.share = true;
      history.size = 10000000;

      plugins = [ pkgs.nix-fast-syntax-highlighting pkgs.nix-zsh-shell-integration ];

      # aliases
      shellAliases = {
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gs = "git status";
        gsb = "git status -sb";

        ".." = "cd ..";
        alacritty_x = "env WINIT_UNIX_BACKEND=x11 alacritty & disown && exit";
        bahs = "bash";
        panik = "rm -rf ~/.furry-porn";
        build_root = "sudo nixos-rebuild switch";
        burn = "pkill -9";
        cat = "bat";
        cdh = "cd $HOME";
        delete_gens = "nix-env -p /nix/var/nix/profiles/system --delete-generations old";
        emacs_headless = "emacs -nw";
        gen_wal = "wal --backend wal --iterative -i $HOME/Downloads/wallpapers/Future/";
        hb = "home-builder switch";
        l = "ls -lF --time-style=long-iso --grid --icons";
        la = "l -a";
        list_gens = "nix-env -p /nix/var/nix/profiles/system --list-generations";
        ll = "ls -l";
        ls = "exa -h --git --color=auto --group-directories-first -s extension";
        lstree = "ls --tree";
        nd = "nix develop -c zsh";
        nix-repl = "source /etc/set-environment && nix repl $(echo $NIX_PATH | perl -pe 's|.*(/nix/store/.*-source/repl.nix).*|\\1|')";
        nu = "sudo nixos-rebuild switch --flake $HOME/.config/nixkpkgs/configuration.nix";
        query = "nix-store --query --requisites /run/current-system | cut -d- -f2- | sort -u";
        query_vim_pkgs = "nix-env -f '<nixpkgs>' -qaP -A vimPlugins";
        re = "systemctl --user restart emacs.service";
        rl = "lorri init && direnv allow";
        scu = "systemctl --user";
        sl = "ls";
        spawn_docker = ''docker run --rm -it -m="12G" --memory-swap="0G" --mount type=bind,src=$HOME/work,dst=/work bap:latest /bin/bash'';
        start_nix_shell = "nix-shell --pure -E 'with import<nixpkgs> {}; callPackage ./. {}";
        tree = "lstree";
        # Keep these two aliases in this specific order, otherwise highlighting gets fucked!!!!
        nixman = "manix '' | grep '^# ' | sed 's/^# (.*) (.*/1/;s/ (.*//;s/^# //' | sed 's/</\\\\</g' | sed 's/>/\\\\>/g'| fzf --ansi --preview=\"manix '{}' | sed 's/type: /> type: /g' | bat -l Markdown --color=always --plain\"";
        opt = "manix '' | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --ansi --preview=\"manix '{}' | sed 's/type: /> type: /g' | bat -l Markdown --color=always --plain\"";
	nvim = "nix run \"github:DieracDelta/vimconf_talk?rev=5fb5f78fcc722b6865a82f4862dd0038fa1ac016\" --no-write-lock-file";

      };
      # keys.sh contains a bunch of my keys
      initExtra = builtins.readFile ./zshrc;
    };
  };
}
