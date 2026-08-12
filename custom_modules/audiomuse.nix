{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.audiomuse-ai;
in
{
  options.services.audiomuse-ai = {
    enable = mkEnableOption "AudioMuse-AI music analysis service";

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port for the Flask API server";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host to bind the Flask API server";
    };

    musicDir = mkOption {
      type = types.path;
      default = "/var/lib/musiclibrary";
      description = "Path to the music library";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/audiomuse-ai";
      description = "Directory for AudioMuse-AI data and configuration";
    };

    user = mkOption {
      type = types.str;
      default = "audiomuse";
      description = "User to run AudioMuse-AI as";
    };

    group = mkOption {
      type = types.str;
      default = "audiomuse";
      description = "Group to run AudioMuse-AI as";
    };

    modelsPackage = mkOption {
      type = types.package;
      default = pkgs.audiomuse-ai-models;
      defaultText = literalExpression "pkgs.audiomuse-ai-models";
      description = "Package containing ONNX models";
    };

    workers = {
      count = mkOption {
        type = types.int;
        default = 2;
        description = "Number of RQ worker processes";
      };
    };

    analysis = {
      forceCpu = mkOption {
        type = types.bool;
        default = false;
        description = "Force AudioMuse analysis workers to use CPU inference instead of CUDA.";
      };

      perSongModelReload = mkOption {
        type = types.bool;
        default = false;
        description = "Reload ONNX sessions after each song for lower memory pressure during analysis.";
      };
    };

    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "PostgreSQL host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "PostgreSQL port";
      };

      name = mkOption {
        type = types.str;
        default = "audiomuse";
        description = "PostgreSQL database name";
      };

      user = mkOption {
        type = types.str;
        default = "audiomuse";
        description = "PostgreSQL user";
      };
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing environment variables (e.g. GEMINI_API_KEY)";
    };

    redis = {
      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Redis host for job queue";
      };

      port = mkOption {
        type = types.port;
        default = 6380;
        description = "Redis port for job queue";
      };
    };
  };

  config = mkIf cfg.enable {
    # PostgreSQL database
    services.postgresql = {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    # Redis for job queue (separate from other Redis instances)
    services.redis.servers.audiomuse = {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
      save = [ ];
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} -"
    ];

    # User and group
    users.users.${cfg.user} = mkIf (cfg.user == "audiomuse") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      extraGroups = [
        "jellyfin"
        "video"
        "render"
      ]; # Access to music library + GPU
    };
    users.groups.${cfg.group} = mkIf (cfg.group == "audiomuse") { };

    # Environment variables for all AudioMuse services
    systemd.services =
      let
        commonEnv = {
          # Flask settings
          FLASK_HOST = cfg.host;
          FLASK_PORT = toString cfg.port;

          # Database - use unix socket for NixOS peer auth
          DATABASE_HOST = cfg.database.host;
          DATABASE_PORT = toString cfg.database.port;
          DATABASE_NAME = cfg.database.name;
          DATABASE_USER = cfg.database.user;
          DATABASE_URL = "postgresql://${cfg.database.user}@/${cfg.database.name}?host=/run/postgresql";

          # Redis
          REDIS_HOST = cfg.redis.host;
          REDIS_PORT = toString cfg.redis.port;
          REDIS_URL = "redis://${cfg.redis.host}:${toString cfg.redis.port}";

          # Paths
          MUSIC_FOLDER = cfg.musicDir;
          DATA_DIR = cfg.dataDir;
          TEMP_DIR = "${cfg.dataDir}/temp_audio";

          # Models - individual paths (code defaults to /app/model/ Docker paths)
          MODELS_PATH = "${cfg.modelsPackage}/models";
          EMBEDDING_MODEL_PATH = "${cfg.modelsPackage}/models/musicnn_embedding.onnx";
          PREDICTION_MODEL_PATH = "${cfg.modelsPackage}/models/musicnn_prediction.onnx";
          CLAP_AUDIO_MODEL_PATH = "${cfg.modelsPackage}/models/model_epoch_36.onnx";
          CLAP_TEXT_MODEL_PATH = "${cfg.modelsPackage}/models/clap_text_model.onnx";
          LYRICS_MODEL_DIR = "${cfg.modelsPackage}/models";
          LYRICS_WHISPER_MODEL_DIR = "${cfg.modelsPackage}/models/whisper-small-onnx";
          SILERO_VAD_ONNX_PATH = "${cfg.modelsPackage}/models/silero_vad.onnx";
          LYRICS_GTE_ONNX_PATH = "${cfg.modelsPackage}/models/gte-multilingual-base-int8.onnx";
          LYRICS_GTE_TOKENIZER_DIR = "${cfg.modelsPackage}/models/gte-multilingual-base";
          HF_HOME = "${cfg.modelsPackage}/cache/huggingface";
          HF_HUB_OFFLINE = "1";
          TRANSFORMERS_OFFLINE = "1";

          # GPU performance tuning (RTX 4090 24GB)
          PER_SONG_MODEL_RELOAD = lib.boolToString cfg.analysis.perSongModelReload;
          CLAP_MINI_BATCH_SIZE = "8"; # Process 8 segments at once
          USE_GPU_CLUSTERING = "true"; # RAPIDS cuML GPU-accelerated clustering

          # Clustering sample size: use 90th percentile of genre counts (~55K tracks vs default ~6.7K)
          STRATIFIED_SAMPLING_TARGET_PERCENTILE = "90";
          MIN_SONGS_PER_GENRE_FOR_STRATIFICATION = "500";
          VOYAGER_EF_CONSTRUCTION = "200";
          VOYAGER_M = "32";

          # CUDA runtime paths:
          # - /run/opengl-driver/lib: NVIDIA driver (libcuda.so.1) for cuML GPU detection
          # - cudatoolkit/lib: libnvrtc.so.12 etc. for cupy runtime compilation
          LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.cudaPackages.cudatoolkit}/lib";
          # CUDA headers for cupy's runtime kernel compilation (cuda_fp16.h etc.)
          CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

          # Reverse proxy support
          ENABLE_PROXY_FIX = "true";

          # AI model for cluster/playlist naming
          AI_MODEL_PROVIDER = "GEMINI";
          GEMINI_MODEL_NAME = "gemini-2.5-flash";
        }
        // lib.optionalAttrs cfg.analysis.forceCpu {
          CUDA_VISIBLE_DEVICES = "-1";
          USE_GPU_CLUSTERING = "false";
        };

        commonServiceConfig = {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          Restart = "always";
          RestartSec = 5;

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [ cfg.dataDir ];
          ReadOnlyPaths = [
            cfg.musicDir
            "${cfg.modelsPackage}"
            "/run/opengl-driver"
          ];

          # GPU access for RAPIDS cuML
          DeviceAllow = [
            "/dev/nvidia0 rw"
            "/dev/nvidia1 rw"
            "/dev/nvidiactl rw"
            "/dev/nvidia-uvm rw"
            "/dev/nvidia-uvm-tools rw"
          ];
          SupplementaryGroups = [
            "video"
            "render"
          ];
        }
        // lib.optionalAttrs (cfg.environmentFile != null) {
          EnvironmentFile = cfg.environmentFile;
        };

        # EnvironmentFile is evaluated after Environment= by systemd, so keep
        # runtime stability knobs on ExecStart where the .env file cannot
        # accidentally override them.
        withRuntimeOverrides =
          command:
          "${pkgs.coreutils}/bin/env "
          + lib.escapeShellArgs (
            [
              "PER_SONG_MODEL_RELOAD=${lib.boolToString cfg.analysis.perSongModelReload}"
              "USE_GPU_CLUSTERING=${lib.boolToString (!cfg.analysis.forceCpu)}"
              "VOYAGER_EF_CONSTRUCTION=200"
              "VOYAGER_M=32"
            ]
            ++ lib.optionals cfg.analysis.forceCpu [
              "CUDA_VISIBLE_DEVICES=-1"
            ]
          )
          + " ${command}";
      in
      {
        # Main Flask API server
        audiomuse-ai = {
          description = "AudioMuse-AI Music Analysis API";
          after = [
            "network.target"
            "postgresql.service"
            "redis-audiomuse.service"
          ];
          wants = [
            "postgresql.service"
            "redis-audiomuse.service"
          ];
          wantedBy = [ "multi-user.target" ];

          environment = commonEnv;

          serviceConfig = commonServiceConfig // {
            ExecStart = withRuntimeOverrides "${pkgs.audiomuse-ai}/bin/audiomuse-ai";
          };
        };

        # RQ Worker (default priority)
        audiomuse-ai-worker = {
          description = "AudioMuse-AI RQ Worker";
          after = [
            "audiomuse-ai.service"
            "redis-audiomuse.service"
          ];
          wants = [ "redis-audiomuse.service" ];
          wantedBy = [ "multi-user.target" ];

          environment = commonEnv;

          serviceConfig = commonServiceConfig // {
            ExecStart = withRuntimeOverrides "${pkgs.audiomuse-ai}/bin/audiomuse-ai-worker";
          };
        };

        # RQ Worker (default priority, instance 2)
        "audiomuse-ai-worker-2" = {
          description = "AudioMuse-AI RQ Worker 2";
          after = [
            "audiomuse-ai.service"
            "redis-audiomuse.service"
          ];
          wants = [ "redis-audiomuse.service" ];
          wantedBy = [ "multi-user.target" ];

          environment = commonEnv;

          serviceConfig = commonServiceConfig // {
            ExecStart = withRuntimeOverrides "${pkgs.audiomuse-ai}/bin/audiomuse-ai-worker";
          };
        };

        # RQ Worker (high priority)
        audiomuse-ai-worker-high = {
          description = "AudioMuse-AI RQ Worker (High Priority)";
          after = [
            "audiomuse-ai.service"
            "redis-audiomuse.service"
          ];
          wants = [ "redis-audiomuse.service" ];
          wantedBy = [ "multi-user.target" ];

          environment = commonEnv;

          serviceConfig = commonServiceConfig // {
            ExecStart = withRuntimeOverrides "${pkgs.audiomuse-ai}/bin/audiomuse-ai-worker-high";
          };
        };
      };

    # Firewall
    networking.firewall.allowedTCPPorts = mkIf (cfg.host == "0.0.0.0") [ cfg.port ];
  };
}
