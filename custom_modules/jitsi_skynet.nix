# Self-hosted Jitsi Meet plus Jitsi Skynet AI services.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.custom_modules.jitsi-skynet;

  enabledModules = [
    "summaries:dispatcher"
    "summaries:executor"
    "customer_configs"
  ]
  ++ lib.optional cfg.enableStreamingWhisper "streaming_whisper"
  ++ lib.optional cfg.enableAssistant "assistant";

  jigasiTranscriptionProperties = {
    "org.jitsi.jigasi.ENABLE_SIP" = "false";
    "org.jitsi.jigasi.ENABLE_TRANSCRIPTION" = "true";
    "org.jitsi.jigasi.rest.jetty.host" = "127.0.0.1";
    "org.jitsi.jigasi.rest.jetty.port" = "8789";
    "net.java.sip.communicator.impl.protocol.jabber.acc-xmpp-1.BOSH_URL_PATTERN" = "https://{host}:${toString cfg.jitsiPort}{subdomain}/http-bind?room={roomName}";
    "org.jitsi.jigasi.xmpp.acc.BOSH_URL_PATTERN" = "https://{host}:${toString cfg.jitsiPort}{subdomain}/http-bind?room={roomName}";
    "org.jitsi.jigasi.transcription.customService" = "org.jitsi.jigasi.transcription.WhisperTranscriptionService";
    "org.jitsi.jigasi.transcription.whisper.websocket_url" = "ws://127.0.0.1:${toString cfg.skynetInternalPort}/streaming-whisper/ws";
    "org.jitsi.jigasi.transcription.SEND_JSON" = "true";
    "org.jitsi.jigasi.transcription.SEND_TXT" = "false";
  };

  formatJavaProperties =
    attrs:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}=${value}") attrs);

  jigasiTranscriptionPropertiesFile =
    pkgs.writeText "jigasi-transcription.properties" (formatJavaProperties jigasiTranscriptionProperties);
in
{
  options.custom_modules.jitsi-skynet = {
    enable = lib.mkOption {
      description = "Enable Jitsi Meet and Jitsi Skynet AI services";
      type = lib.types.bool;
      default = false;
    };

    domain = lib.mkOption {
      description = "Public domain used for the desktop services";
      type = lib.types.str;
      default = "office-desktop.tail5ca7.ts.net";
    };

    jitsiPort = lib.mkOption {
      description = "External HTTPS port for Jitsi Meet";
      type = lib.types.port;
      default = 8445;
    };

    jitsiInternalPort = lib.mkOption {
      description = "Loopback port where nginx serves Jitsi Meet";
      type = lib.types.port;
      default = 5281;
    };

    skynetPort = lib.mkOption {
      description = "External HTTPS port for Skynet";
      type = lib.types.port;
      default = 8446;
    };

    skynetInternalPort = lib.mkOption {
      description = "Loopback port where the Skynet API listens";
      type = lib.types.port;
      default = 8007;
    };

    skynetMetricsPort = lib.mkOption {
      description = "Loopback port where Skynet exposes Prometheus metrics";
      type = lib.types.port;
      default = 8008;
    };

    redisPort = lib.mkOption {
      description = "Loopback Redis port for Skynet";
      type = lib.types.port;
      default = 6381;
    };

    ollamaModel = lib.mkOption {
      description = "Local Ollama model Skynet should use for summaries";
      type = lib.types.str;
      default = "llama3.1";
    };

    enableStreamingWhisper = lib.mkOption {
      description = "Enable Skynet live transcription with Faster Whisper";
      type = lib.types.bool;
      default = true;
    };

    whisperModel = lib.mkOption {
      description = "Faster Whisper model name to use for live transcription";
      type = lib.types.str;
      default = "large-v3";
    };

    enableAssistant = lib.mkOption {
      description = "Enable Skynet RAG assistant module";
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.enableAssistant;
        message = "custom_modules.jitsi-skynet.enableAssistant is not packaged yet because Skynet's flashrank/kreuzberg RAG dependencies are not in nixpkgs.";
      }
    ];

    services.jitsi-meet = {
      enable = true;
      hostName = cfg.domain;
      caddy.enable = false;
      nginx.enable = true;
      jigasi.enable = cfg.enableStreamingWhisper;
      excalidraw.enable = false;
      prosody.lockdown = true;
      config = {
        bosh = "//${cfg.domain}:${toString cfg.jitsiPort}/http-bind";
        websocket = "wss://${cfg.domain}:${toString cfg.jitsiPort}/xmpp-websocket";
        enableWelcomePage = true;
        prejoinPageEnabled = true;
        disableThirdPartyRequests = true;
        p2p.enabled = true;
        analytics.disabled = true;
      }
      // lib.optionalAttrs cfg.enableStreamingWhisper {
        transcription = {
          enabled = true;
          useAppLanguage = false;
          preferredLanguage = "en-US";
          autoCaptionOnTranscribe = true;
          disableClosedCaptions = false;
          renderTranscriptDetails = true;
        };
      };
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
        DEFAULT_REMOTE_DISPLAY_NAME = "Guest";
      };
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      listen = [
        {
          addr = "127.0.0.1";
          port = cfg.jitsiInternalPort;
          ssl = false;
        }
      ];
      enableACME = lib.mkForce false;
      forceSSL = lib.mkForce false;
    };

    services.jitsi-videobridge = {
      openFirewall = true;
      colibriRestApi = true;
    };

    services.jigasi = lib.mkIf cfg.enableStreamingWhisper {
      bridgeMuc = lib.mkForce "jigasibrewery@internal.auth.${cfg.domain}";
      config = jigasiTranscriptionProperties;
    };

    services.jicofo.config.jicofo.jigasi = lib.mkIf cfg.enableStreamingWhisper {
      brewery-jid = "jigasibrewery@internal.auth.${cfg.domain}";
      xmpp-connection-name = "Service";
      use-private-address-connectivity = false;
    };

    services.jicofo.config.jicofo.xmpp.trusted-domains =
      lib.mkIf cfg.enableStreamingWhisper [ cfg.domain ];

    services.redis.servers.skynet = {
      enable = true;
      bind = "127.0.0.1";
      port = cfg.redisPort;
      openFirewall = false;
    };

    services.ollama = {
      enable = true;
      loadModels = lib.mkAfter [ cfg.ollamaModel ];
    };

    users.groups.skynet = { };
    users.users.skynet = {
      isSystemUser = true;
      group = "skynet";
      home = "/var/lib/skynet";
      createHome = true;
      extraGroups = [
        "render"
        "video"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/skynet 0750 skynet skynet -"
      "d /var/lib/skynet/models 0750 skynet skynet -"
      "d /var/lib/skynet/models/streaming-whisper 0750 skynet skynet -"
      "d /var/lib/skynet/huggingface 0750 skynet skynet -"
      "d /var/lib/skynet/vector-store 0750 skynet skynet -"
    ];

    systemd.services.skynet = {
      description = "Jitsi Skynet AI API server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "ollama.service"
        "redis-skynet.service"
      ];
      wants = [
        "network-online.target"
        "ollama.service"
        "redis-skynet.service"
      ];

      path = [
        pkgs.ffmpeg-headless
        pkgs.gitMinimal
      ];

      environment = {
        BYPASS_AUTHORIZATION = "true";
        CUDA_VISIBLE_DEVICES = "0";
        ENABLE_METRICS = "true";
        ENABLED_MODULES = lib.concatStringsSep "," enabledModules;
        HF_HOME = "/var/lib/skynet/huggingface";
        LLAMA_PATH = cfg.ollamaModel;
        LLAMA_N_CTX = "80000";
        LOG_LEVEL = "INFO";
        OPENAI_API_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
        REDIS_HOST = "127.0.0.1";
        REDIS_PORT = toString cfg.redisPort;
        SKYNET_LISTEN_IP = "127.0.0.1";
        SKYNET_METRICS_PORT = toString cfg.skynetMetricsPort;
        SKYNET_PORT = toString cfg.skynetInternalPort;
        VECTOR_STORE_PATH = "/var/lib/skynet/vector-store";
        WHISPER_COMPUTE_TYPE = "float16";
        WHISPER_DEVICE = "cuda";
        WHISPER_GPU_INDICES = "0";
        WHISPER_MODEL_NAME = cfg.whisperModel;
        WHISPER_MODEL_PATH = "/var/lib/skynet/models/streaming-whisper";
      };

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.skynet}";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "skynet";
        Group = "skynet";
        WorkingDirectory = "/var/lib/skynet";
        StateDirectory = "skynet";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/skynet" ];
        SupplementaryGroups = [
          "render"
          "video"
        ];
      };
    };

    systemd.services.jigasi = lib.mkIf cfg.enableStreamingWhisper {
      after = [
        "prosody.service"
        "skynet.service"
      ];
      wants = [ "skynet.service" ];
      partOf = [ "prosody.service" ];
      environment.LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.openssl ];
      preStart = lib.mkAfter ''
        cat >>/tmp/jigasi-home/sip-communicator.properties <<'EOF'
        ${formatJavaProperties jigasiTranscriptionProperties}
        EOF
      '';
    };

    systemd.services.jicofo = lib.mkIf cfg.enableStreamingWhisper {
      partOf = [ "prosody.service" ];
      restartTriggers = [ jigasiTranscriptionPropertiesFile ];
    };

    systemd.services.prosody = lib.mkIf cfg.enableStreamingWhisper {
      reloadIfChanged = lib.mkForce false;
      restartIfChanged = true;
    };

    services.caddy.virtualHosts."${cfg.domain}:${toString cfg.jitsiPort}".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.jitsiInternalPort}
    '';

    services.caddy.virtualHosts."${cfg.domain}:${toString cfg.skynetPort}".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.skynetInternalPort}
    '';

    services.caddy.virtualHosts.${cfg.domain}.extraConfig = lib.mkBefore ''
      redir /skynet /skynet/
      handle_path /skynet/* {
        reverse_proxy 127.0.0.1:${toString cfg.skynetInternalPort}
      }
    '';

    networking.firewall.allowedTCPPorts = [
      cfg.jitsiPort
      cfg.skynetPort
    ];

    services.homepage-dashboard.services = lib.mkAfter [
      {
        "Communication" = [
          {
            "Jitsi Meet" = {
              icon = "jitsi-meet";
              href = "https://${cfg.domain}:${toString cfg.jitsiPort}";
              description = "Private video meetings";
            };
          }
        ];
      }
    ];
  };
}
