# Shared overlay for tmux-search-panes plugin
# Used by both x86 (via overlays/) and ARM (directly in flake.nix)
_: final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    search-panes = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "search-panes";
      version = "0-unstable-2025-04-22";
      src = final.fetchFromGitHub {
        owner = "multi-io";
        repo = "tmux-search-panes";
        rev = "3996b5c56c6be69d3a85ef26065b1877d9ac71c6";
        hash = "sha256-Z9Gu4v2LAyG6UxXVLTvQUz1wU4PaJlBQXjLiSzfSP7s=";
      };
      rtpFilePath = "tmux-search-panes.tmux";
      nativeBuildInputs = [ final.makeWrapper ];
      postInstall = ''
        for f in search-panes.sh _fzf-and-switch.sh _render-preview.sh; do
          chmod +x $target/bin/$f
          wrapProgram $target/bin/$f \
            --prefix PATH : ${
              final.lib.makeBinPath [
                final.coreutils
                final.fzf
                final.gnugrep
                final.gnused
                final.tmux
              ]
            }
        done
      '';
      meta = {
        homepage = "https://github.com/multi-io/tmux-search-panes";
        description = "Tmux plugin for fulltext search across all panes";
        license = final.lib.licenses.mit;
        platforms = final.lib.platforms.unix;
      };
    };
  };
}
