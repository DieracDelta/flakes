{ config, pkgs, ... }:

{
# Let Home Manager install and manage itself.
	programs.home-manager.enable = true;

# This value determines the Home Manager release that your
# configuration is compatible with. This helps avoid breakage
# when a new Home Manager release introduces backwards
# incompatible changes.
#
# You can update Home Manager without changing this value. See
# the Home Manager release notes for a list of state version
# changes in each release.
	home.stateVersion = "19.09";
	programs.fzf.enableZshIntegration = true;
	programs.zsh.enable = true;
	programs.zsh.enableCompletion = true;
	programs.zsh.enableAutosuggestions = true;
	programs.zsh.autocd = true;
#programs.zsh.defaultKeymap = "vicmd";
	programs.zsh.history.extended = true;
	programs.zsh.history.ignoreDups = true;
	programs.zsh.history.path = ".zsh_history";
	programs.zsh.history.save = 10000000;
	programs.zsh.history.share = true;
	programs.zsh.history.size = 10000000;
	programs.zsh.oh-my-zsh.enable = true;
#programs.zsh.oh-my-zsh.plugins = [ "git" "sudo" "fast-syntax-highlighting" "fzf-z" "z" ];
	programs.zsh.oh-my-zsh.plugins = [ "git" "sudo" "z" ];

# aliases
	programs.zsh.shellAliases = {
		ll = "ls -l";
		".." = "cd ..";
		"query" = "nix-store --query --requisites /run/current-system | cut -d- -f2- | sort -u";
		"hb" = "home-builder switch";
		"build_root" = "sudo nixos-rebuild switch";
	};
	programs.zsh.initExtra = ''
		cat $HOME/.cache/wal/sequences
	'';
	programs.zsh.oh-my-zsh.theme = "robbyrussell";
	programs.zsh.plugins = 
		[
			{
				name = "fast-syntax-highlighting";
				src = pkgs.fetchFromGitHub {
					owner = "zdharma";
					repo = "fast-syntax-highlighting";
					rev = "303eeee81859094385605f7c978801748d71056c";
					sha256 = "0y0jgkj9va8ns479x3dhzk8bwd58a1kcvm4s2mk6x3n19w7ynmnv";
				};
			}
			{
				name = "fzf-z";
				src = pkgs.fetchFromGitHub {
					owner = "andrewferrier";
					repo = "fzf-z";
					rev = "2db04c704360b5b303fb5708686cbfd198c6bf4f";
					sha256 = "1ib98j7v6hy3x43dcli59q5rpg9bamrg335zc4fw91hk6jcxvy45";
				};
			}
		];

	programs.tmux.enable = true;
	programs.tmux.historyLimit = 1000000;
	programs.tmux.extraConfig = ''
		unbind C-b
		set -g prefix C-Space
		bind C-Space send-prefix

		setw -g mode-keys vi
		setw -g status-keys vi
	'';

	#wayland.windowManager.sway.enable = true;
	#wayland.windowManager.sway.extraSessionCommands = 
	#	''
	#	export SDL_VIDEODRIVER=wayland
	#	export QT_QPA_PLATFORM=wayland
	#	export QT_WAYLAND_DISABLE_WINDOWDECORATIONS="1"
	#	export _JAVA_AWT_WM_NONREPARENTING=1
	#	'';
	#wayland.windowManager.sway.systemdIntegration = true;
	#wayland.windowManager.sway.wrapperFeatures.gtk = true;
	#
	

	#programs.neovim.enable = true;
	#programs.neovim.extraConfig = 
	#''
	#'';
	#programs.neovim.plugins = [ ];
	#programs.neovim.viAlias = true;
	#programs.neovim.vimAlias = true;
	#programs.neovim.withNodeJs = true;
	#programs.neovim.withPython = true;
	#programs.neovim.withPython3 = true;
	#programs.neovim.withRuby = true;

	#import <nixpkgs> { overlays = [ rootbar ] ; }
	nixpkgs.overlays = [ "./overs/rootbar" ] ;
	manual.html.enable = true;


}
