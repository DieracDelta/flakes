final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    gruvbox-themes = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "gruvbox-themes";
      version = "unstable-2026-01-25";
      src = final.fetchFromGitHub {
        owner = "DieracDelta";
        repo = "tmux-gruvbox";
        rev = "1ddc909d16708e0d5ffbb33022ff32574ea70d00";
        hash = "sha256-LeYE5X3pa0cc0pRvu2OfodB1v7rPDenomz0vPnPlZSo=";
      };
      rtpFilePath = "gruvbox-tpm.tmux";
    };
  };
}
