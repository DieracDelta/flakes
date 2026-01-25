final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    gruvbox-themes = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "gruvbox-themes";
      version = "unstable-2026-01-25";
      src = final.fetchFromGitHub {
        owner = "DieracDelta";
        repo = "tmux-gruvbox";
        rev = "d4c9ceb38eee806b9ce13340e56a5ec6c74b4cc8";
        hash = "sha256-psEDGV/670u1TapOLAsIzGq5zfoJtYNnRrJmfeDtPiU=";
      };
      rtpFilePath = "gruvbox-tpm.tmux";
    };
  };
}
