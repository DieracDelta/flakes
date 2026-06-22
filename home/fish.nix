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
    if pkgs.stdenv.isDarwin then
      {
        # Darwin - Forest Green theme
        primary = "#7ec47e"; # Green accent
        secondary = "#5f9e5f"; # Darker green
        directory = "#7ec47e";
        git = "#c4c47e"; # Yellow-green
        error = "#c47e7e"; # Muted red
        hostname = "#9cb398";
        mute = "#51635b";
      }
    else if pkgs.stdenv.hostPlatform.isAarch64 then
      {
        # NixOS ARM - Crimson theme
        primary = "#c47070"; # Red accent
        secondary = "#9e4f4f"; # Darker red
        directory = "#c47070";
        git = "#c4a07e"; # Orange-ish
        error = "#c48060"; # Orange for errors (since red is primary)
        hostname = "#b39c98";
        mute = "#6e5552";
      }
    else
      {
        # x86_64 - Original gruvbox
        primary = "#fabd2f"; # Gruvbox yellow
        secondary = "#d79921"; # Darker yellow
        directory = "#83a598"; # Gruvbox blue
        git = "#b8bb26"; # Gruvbox green
        error = "#fb4934"; # Gruvbox red
        hostname = "#bdae93";
        mute = "#665c54";
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
        {
          name = "async-prompt";
          inherit (async-prompt) src;
        }
        {
          name = "pure";
          inherit (pure) src;
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
        set -g async_prompt_enable 1
        set -g async_prompt_functions fish_prompt
        set -g async_prompt_inherit_variables \
          CMD_DURATION \
          SHLVL \
          fish_bind_mode \
          pipestatus \
          status \
          pure_begin_prompt_with_current_directory \
          pure_color_at_sign \
          pure_color_current_directory \
          pure_color_git_branch \
          pure_color_git_dirty \
          pure_color_git_stash \
          pure_color_git_unpulled_commits \
          pure_color_git_unpushed_commits \
          pure_color_hostname \
          pure_color_prompt_on_error \
          pure_color_prompt_on_success \
          pure_color_system_time \
          pure_color_username_normal \
          pure_color_username_root \
          pure_enable_single_line_prompt \
          pure_show_system_time \
          pure_shorten_prompt_current_directory_length \
          pure_symbol_prompt \
          pure_symbol_reverse_prompt \
          pure_truncate_prompt_current_directory_keeps

        set -g pure_enable_single_line_prompt true
        set -g pure_begin_prompt_with_current_directory true
        set -g pure_shorten_prompt_current_directory_length 1
        set -g pure_truncate_prompt_current_directory_keeps 2

        set -g pure_show_system_time true
        set -g pure_color_system_time "${promptColors.mute}"

        set -g pure_symbol_prompt "❯"
        set -g pure_symbol_reverse_prompt "❮"
        set -g pure_color_prompt_on_success "${promptColors.primary}"
        set -g pure_color_prompt_on_error "${promptColors.error}"
        set -g pure_color_current_directory "${promptColors.directory}"
        set -g pure_color_git_branch "${promptColors.git}"
        set -g pure_color_git_dirty "${promptColors.git}"
        set -g pure_color_git_stash "${promptColors.git}"
        set -g pure_color_git_unpulled_commits "${promptColors.git}"
        set -g pure_color_git_unpushed_commits "${promptColors.git}"
        set -g pure_color_hostname "${promptColors.hostname}"
        set -g pure_color_at_sign "${promptColors.mute}"
        set -g pure_color_username_normal "${promptColors.primary}"
        set -g pure_color_username_root "${promptColors.error}"

        ${builtins.readFile ./config.fish}
      '';
      # tirith init --shell fish | source
    };
  };
}
