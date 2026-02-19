{ tmux-revive-llms }:
final: prev:
let
  pluginSrc = final.runCommand "tmux-revive-llms-plugin-src" { } ''
    mkdir -p "$out"
    cp ${tmux-revive-llms}/revive.tmux "$out/revive.tmux"
  '';
in
{
  tmuxPlugins = prev.tmuxPlugins // {
    revive-llms = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "tmux-revive-llms";
      version = "unstable";
      src = pluginSrc;
      rtpFilePath = "revive.tmux";
    };
  };

  tmux-revive = tmux-revive-llms.packages.${final.stdenv.hostPlatform.system}.tmux-revive;
}
