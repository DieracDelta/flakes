final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    resurrect = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "resurrect";
      version = "unstable-2023-03-06";
      src = final.fetchFromGitHub {
        owner = "tmux-plugins";
        repo = "tmux-resurrect";
        rev = "cff343cf9e81983d3da0c8562b01616f12e8d548";
        hash = "sha256-2ZM23RQps2XO2OYX9NTZj5yIUZEv4ggYzjrJ9RxxLLg=";
        fetchSubmodules = true;
      };
    };
    continuum = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "continuum";
      version = "unstable-2024-01-20";
      src = final.fetchFromGitHub {
        owner = "tmux-plugins";
        repo = "tmux-continuum";
        rev = "0698e8f4b17d6454c71bf5212895ec055c578da0";
        hash = "sha256-W71QyLwC/MXz3bcLR2aJeWcoXFI/A3itjpcWKAdVFJY=";
      };
    };
  };
}
