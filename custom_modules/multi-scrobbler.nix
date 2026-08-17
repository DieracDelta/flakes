{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.custom_modules.multi-scrobbler;
  stateDir = "/var/lib/multi-scrobbler";
  audiomuseSource = cfg.audiomuseMusicServer;
  listenBrainzEndpoint = cfg.listenBrainzEndpoint;
  listenBrainzEndpointJson = pkgs.writeText "multi-scrobbler-listenbrainz-endpoint-source.json" (
    builtins.toJSON {
      name = listenBrainzEndpoint.sourceName;
      enable = true;
      data = {
        token = listenBrainzEndpoint.token;
      }
      // optionalAttrs (listenBrainzEndpoint.slug != null) {
        slug = listenBrainzEndpoint.slug;
      };
    }
  );
  audiomuseSourceJson = pkgs.writeText "multi-scrobbler-audiomuse-music-server-source.json" (
    builtins.toJSON {
      name = audiomuseSource.sourceName;
      enable = true;
      data = {
        url = audiomuseSource.url;
        user = audiomuseSource.user;
        password = "[[${audiomuseSource.apiKeyEnvVar}]]";
        legacyAuthentication = true;
        interval = audiomuseSource.interval;
        maxInterval = audiomuseSource.maxInterval;
      }
      // optionalAttrs (audiomuseSource.usersAllow != [ ]) {
        usersAllow = audiomuseSource.usersAllow;
      };
    }
  );
in
{
  options.custom_modules.multi-scrobbler = {
    enable = mkEnableOption "Multi-scrobbler service";

    port = mkOption {
      type = types.port;
      default = 9078;
      description = "Port for multi-scrobbler web UI";
    };

    baseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Base URL for multi-scrobbler (for OAuth callbacks)";
    };

    audiomuseMusicServer = {
      enable = mkEnableOption "AudioMuse-AI MusicServer as a multi-scrobbler Subsonic source";

      sourceName = mkOption {
        type = types.str;
        default = "audiomuse-music-server";
        description = "Name for the managed AudioMuse-AI MusicServer Subsonic source";
      };

      url = mkOption {
        type = types.str;
        default = "http://127.0.0.1:${toString config.services.audiomuse-ai-music-server.port}";
        description = "AudioMuse-AI MusicServer Subsonic API base URL";
      };

      user = mkOption {
        type = types.str;
        default = "admin";
        description = "AudioMuse-AI MusicServer Subsonic user";
      };

      usersAllow = mkOption {
        type = types.listOf types.str;
        default = [ "admin" ];
        description = "AudioMuse-AI MusicServer users whose plays multi-scrobbler should forward";
      };

      apiKeyEnvVar = mkOption {
        type = types.str;
        default = "AUDIOMUSE_MUSIC_SERVER_API_KEY";
        description = "Environment variable containing the AudioMuse-AI MusicServer API key";
      };

      environmentFile = mkOption {
        type = types.path;
        default = "/var/lib/multi-scrobbler/audiomuse-music-server.env";
        description = "Optional environment file containing the AudioMuse-AI MusicServer API key";
      };

      interval = mkOption {
        type = types.ints.positive;
        default = 10;
        description = "Polling interval in seconds for the AudioMuse-AI MusicServer source";
      };

      maxInterval = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Maximum backoff polling interval in seconds for the AudioMuse-AI MusicServer source";
      };
    };

    listenBrainzEndpoint = {
      enable = mkEnableOption "managed ListenBrainz endpoint source";

      sourceName = mkOption {
        type = types.str;
        default = "listenbrainz-endpoint";
        description = "Name for the managed ListenBrainz endpoint source.";
      };

      token = mkOption {
        type = types.str;
        default = "local-multi-scrobbler-listenbrainz";
        description = "Token accepted by the managed ListenBrainz endpoint source.";
      };

      slug = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional ListenBrainz endpoint slug. Leave null for the standard /1/submit-listens route.";
      };
    };
  };

  config = mkIf cfg.enable {
    # User/Group
    users.users.multi-scrobbler = {
      isSystemUser = true;
      group = "multi-scrobbler";
      home = stateDir;
      createHome = true;
      description = "Multi-scrobbler service user";
    };
    users.groups.multi-scrobbler = { };

    # Directory setup
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 multi-scrobbler multi-scrobbler -"
    ];

    # Multi-scrobbler service
    systemd.services.multi-scrobbler = {
      description = "Multi-Scrobbler";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [
        pkgs.coreutils
        pkgs.jq
      ];

      unitConfig = {
        StartLimitIntervalSec = "5min";
        StartLimitBurst = 5;
      };

      environment = {
        NODE_ENV = "production";
        DEBUG_MODE = "false";
        CONFIG_DIR = stateDir;
        PORT = toString cfg.port;
        BASE_URL = if cfg.baseUrl != null then cfg.baseUrl else "http://127.0.0.1:${toString cfg.port}";
      };

      preStart = ''
        set -euo pipefail

        app_cfg_file=${stateDir}/config.json
        app_base_file=$(mktemp)
        app_tmp_file=$(mktemp)

        cleanup_app_config() {
          rm -f "$app_base_file" "$app_tmp_file"
        }
        trap cleanup_app_config EXIT

        if [ -s "$app_cfg_file" ]; then
          jq 'if type == "object" then . else {} end' "$app_cfg_file" > "$app_base_file"
        else
          printf '{}\n' > "$app_base_file"
        fi

        jq '.debugMode = false | .logging = ((.logging // {}) + { file: false, console: "warn", level: "warn" })' "$app_base_file" > "$app_tmp_file"
        install -m 0600 "$app_tmp_file" "$app_cfg_file"
      ''
      + optionalString listenBrainzEndpoint.enable ''
        set -euo pipefail

        cfg_file=${stateDir}/endpointlz.json
        base_file=$(mktemp)
        tmp_file=$(mktemp)
        source_name=${escapeShellArg listenBrainzEndpoint.sourceName}

        cleanup() {
          rm -f "$base_file" "$tmp_file"
        }
        trap cleanup EXIT

        normalize_sources() {
          if [ -s "$cfg_file" ]; then
            jq 'if type == "array" then . elif type == "object" then [.] else [] end' "$cfg_file"
          else
            printf '[]\n'
          fi
        }

        normalize_sources > "$base_file"
        jq \
          --arg name "$source_name" \
          --slurpfile source ${listenBrainzEndpointJson} \
          'map(select(.name != $name)) + [$source[0]]' \
          "$base_file" > "$tmp_file"
        install -m 0600 "$tmp_file" "$cfg_file"
      ''
      + optionalString audiomuseSource.enable ''
        set -euo pipefail

        cfg_file=${stateDir}/subsonic.json
        base_file=$(mktemp)
        tmp_file=$(mktemp)
        api_key_var=${escapeShellArg audiomuseSource.apiKeyEnvVar}
        source_name=${escapeShellArg audiomuseSource.sourceName}

        cleanup() {
          rm -f "$base_file" "$tmp_file"
        }
        trap cleanup EXIT

        normalize_sources() {
          if [ -s "$cfg_file" ]; then
            jq 'if type == "array" then . elif type == "object" then [.] else [] end' "$cfg_file"
          else
            printf '[]\n'
          fi
        }

        if [ -z "$(printenv "$api_key_var" || true)" ]; then
          normalize_sources > "$base_file"
          jq --arg name "$source_name" 'map(select(.name != $name))' "$base_file" > "$tmp_file"
          install -m 0600 "$tmp_file" "$cfg_file"
          echo "AudioMuse-AI MusicServer source skipped; $api_key_var is not set"
        else
          normalize_sources > "$base_file"
          jq \
            --arg name "$source_name" \
            --slurpfile source ${audiomuseSourceJson} \
            'map(select(.name != $name)) + [$source[0]]' \
            "$base_file" > "$tmp_file"
          install -m 0600 "$tmp_file" "$cfg_file"
        fi
      '';

      postStart = ''
        healthy=0
        for attempt in $(seq 1 30); do
          if ${lib.getExe pkgs.curl} --max-time 2 --silent --show-error --output /dev/null \
            "http://127.0.0.1:${toString cfg.port}/"; then
            healthy=$((healthy + 1))
            if [ "$healthy" -ge 5 ]; then
              exit 0
            fi
          else
            healthy=0
          fi
          sleep 1
        done
        echo "Multi-scrobbler did not remain healthy for five consecutive probes within 30 seconds" >&2
        exit 1
      '';

      serviceConfig = {
        Type = "simple";
        User = "multi-scrobbler";
        Group = "multi-scrobbler";
        ExecStart = "${pkgs.multi-scrobbler}/bin/multi-scrobbler";
        EnvironmentFile = optional audiomuseSource.enable "-${audiomuseSource.environmentFile}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ stateDir ];
      };
    };
  };
}
