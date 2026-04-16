# Ollama and Open WebUI configuration
# Local LLM inference with web interface
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.ollama;
in
{
  options.custom_modules.ollama.enable = lib.mkOption {
    description = "Enable Ollama LLM inference server with Open WebUI";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      port = 11111;
      openFirewall = true;
      host = "0.0.0.0";
    };

    services.open-webui = {
      openFirewall = true;
      enable = false;
      host = "0.0.0.0";
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11111";
        WEBUI_AUTH = "False";
      };
    };

    networking.firewall.allowedTCPPorts = [
      11434 # Default ollama port (in case needed)
    ];
  };
}
