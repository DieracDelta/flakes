{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.profiles.zsh;

  # Host-specific prompt colors matching tmux themes
  promptColors =
    if pkgs.stdenv.isDarwin then {
      # Darwin - Forest Green theme
      primary = "#7ec47e";      # Green accent
      secondary = "#5f9e5f";    # Darker green
      directory = "#7ec47e";
      git = "#c4c47e";          # Yellow-green
      error = "#c47e7e";        # Muted red
      hostname = "#9cb398";
    }
    else if pkgs.stdenv.hostPlatform.isAarch64 then {
      # NixOS ARM - Crimson theme
      primary = "#c47070";      # Red accent
      secondary = "#9e4f4f";    # Darker red
      directory = "#c47070";
      git = "#c4a07e";          # Orange-ish
      error = "#c48060";        # Orange for errors (since red is primary)
      hostname = "#b39c98";
    }
    else {
      # x86_64 - Original gruvbox
      primary = "#fabd2f";      # Gruvbox yellow
      secondary = "#d79921";    # Darker yellow
      directory = "#83a598";    # Gruvbox blue
      git = "#b8bb26";          # Gruvbox green
      error = "#fb4934";        # Gruvbox red
      hostname = "#bdae93";
    };
in
{
  # TODO rename to shell. It's not zsh anymore
  options.profiles.zsh.enable = lib.mkOption {
    description = "Enable shell integrations";
    type = with lib.types; bool;
    default = true;
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.tirith ];

    programs.starship = {
      settings = {
        add_newline = false;
        git_branch.disabled = false;
        directory.fish_style_pwd_dir_length = 1; # turn on fish directory truncation
        directory.truncation_length = 2; # number of directories not to truncate

        # Host-specific colors
        directory.style = "bold ${promptColors.directory}";
        git_branch.style = "bold ${promptColors.git}";
        git_status.style = "${promptColors.git}";
        character = {
          success_symbol = "[❯](bold ${promptColors.primary})";
          error_symbol = "[❯](bold ${promptColors.error})";
        };
        hostname = {
          style = "bold ${promptColors.hostname}";
          ssh_only = false;
        };
        username.style_user = "bold ${promptColors.primary}";
      };
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    programs.dircolors = {
      enable = true;
      enableFishIntegration = true;
    };

    programs.fish = {
      enable = true;
      plugins = with pkgs.fishPlugins; [
        # TODO autopair.fish maybe?
        # https://github.com/jorgebucaran/autopair.fish
        {
          name = "puffer";
          inherit (puffer) src;
        }
      ];
      shellAliases = {
        ga = "git add";
        gc = "git commit";
        gcm = "git commit -m";
        gs = "git status";
        gsb = "git status -sb";

        ".." = "cd ..";
        bahs = "bash";
        cat = "bat";
        ccat = "command cat";
        cdh = "cd $HOME";
        l = "ls -lF --time-style=long-iso --grid --icons";
        la = "l -a";
        list_gens = "nix-env -p /nix/var/nix/profiles/system --list-generations";
        ll = "ls -l";
        ls = "eza -h --git --color=auto --group-directories-first -s extension";
        ccn = ''nix run "github:sadjow/claude-code-nix"'';
        nd = "nix develop -c fish";
        sl = "ls";
        # yes this is morally wrong
        # no I don't care
        # nn =
        #   let
        #     nvimPath =
        #       (if pkgs.stdenv.isDarwin then " /Users/jrestivo/dev/vimconfig/result/bin/nvim" else "")
        #       + (
        #         if pkgs.stdenv.isLinux then
        #           "${pkgs.coreutils}/bin/nice -n -10 ${pkgs.util-linux}/bin/ionice -c2 -n0  /home/jrestivo/dev/vimconfig/result/bin/nvim"
        #         else
        #           ""
        #       );
        #   in
        #   nvimPath;
        # ''
        #   ${nvimPath} $argv &;
        #   set pid $last_pid;
        #   renice -n -10 -p $pid;
        #   ionice -c2 -n0 -p $pid;
        #   fg $pid
        # '';
      };
      # keys.sh contains a bunch of my keys
      interactiveShellInit = ''
        ${builtins.readFile ./config.fish}
        tirith init --shell fish | source
      '';
    };
  };
}
