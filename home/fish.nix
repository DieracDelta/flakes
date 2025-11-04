{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = config.profiles.zsh;
in
{
  # TODO rename to shell. It's not zsh anymore
  options.profiles.zsh.enable = lib.mkOption {
    description = "Enable shell integrations";
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
        nd = "nix develop -c fish";
        sl = "ls";
        # yes this is morally wrong
        # no I don't care
        nn =
          let
            nvimPath =
              (if pkgs.stdenv.isDarwin then " /Users/jrestivo/dev/vimconfig/result/bin/nvim" else "")
              + (
                if pkgs.stdenv.isLinux then
                  "${pkgs.coreutils}/bin/nice -n -10 ${pkgs.util-linux}/bin/ionice -c2 -n0  /home/jrestivo/dev/vimconfig/result/bin/nvim"
                else
                  ""
              );
          in
          nvimPath;
        # ''
        #   ${nvimPath} $argv &;
        #   set pid $last_pid;
        #   renice -n -10 -p $pid;
        #   ionice -c2 -n0 -p $pid;
        #   fg $pid
        # '';
      };
      # keys.sh contains a bunch of my keys
      interactiveShellInit = builtins.readFile ./config.fish;
    };
  };
}
