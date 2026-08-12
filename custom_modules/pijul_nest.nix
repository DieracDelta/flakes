{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  cfg = config.custom_modules.pijul-nest;

  # Upstream main currently materializes thousands of unresolved Pijul conflict
  # markers. This is the newest clean state immediately before the conflicting
  # change: QEB77DYAKDVYLSN7MKZFCO4UY4EP5TUSXVH6L7LHQ2NDCBD4HHFQC (2026-06-06).
  fetchedNestSource = nestPkgs.fetchpijul {
    name = "pijul-nest-source";
    url = "https://nest.pijul.com/pmeunier/nest";
    channel = "main";
    state = "W6LZBBLQ2GJPCTT7BRJHHYIRSNLVJXR47BIUCYGOVJOWQYOSVCKQC";
    hash = "sha256-palxC7dl8l4+3yhp3Cga0X+L5AZ8MARaFLBXmbLvUa8=";
  };
  nestHooks = nestPkgs.writeText "pijul-nest-hooks.server.ts" ''
    import type { Handle, HandleFetch } from '@sveltejs/kit';

    export const handleFetch: HandleFetch = async ({ event, request, fetch }) => {
      if (request.url.startsWith(import.meta.env.VITE_SERVER)) {
        request = new Request(
          request.url.replace(import.meta.env.VITE_SERVER, import.meta.env.VITE_LOCAL_SERVER),
          request
        );
      }

      const cookie = event.request.headers.get('cookie');
      if (cookie) {
        request.headers.set('cookie', cookie);
      }

      const response = await fetch(request);
      event.locals.fetchResponses ??= [];
      event.locals.fetchResponses.push(response);
      return response;
    };

    export const handle: Handle = async ({ event, resolve }) => {
      const response = await resolve(event, {
        filterSerializedResponseHeaders: (name) => name === 'set-cookie'
      });

      for (const upstreamResponse of event.locals.fetchResponses ?? []) {
        const setCookie = upstreamResponse.headers.get('set-cookie');
        if (setCookie) {
          response.headers.append('set-cookie', setCookie);
        }
      }

      return response;
    };
  '';

  # The clean branch declares repository::dot_pijul but omitted its source
  # file. Restore that file byte-for-byte from the change that introduced it:
  # PCR2LDLTK6XVSBXJL6IMGQP7GSE5UNFCT6WRM2H5EPQ2AZWFRCFAC.
  nestSource = nestPkgs.runCommand "pijul-nest-patched-source" { } ''
    cp -R ${fetchedNestSource} "$out"
    chmod -R u+w "$out"
    install -m 0644 ${./pijul_nest/dot_pijul.rs} \
      "$out/api/src/repository/dot_pijul.rs"

    # SSR API requests receive the CSRF cookie on the Nest UI server. Upstream
    # intended to forward those Set-Cookie headers to the browser but omitted
    # recording fetch responses, making every settings form fail with 403 {}.
    # Also remove upstream request/cookie dumps from the system journal.
    install -m 0644 ${nestHooks} "$out/ui/src/hooks.server.ts"

    # Upstream marks every registration as awaiting confirmation even when no
    # SMTP transport is configured, while its no-mail sender reports success.
    # This private tailnet deployment intentionally permits immediate signup.
    substituteInPlace "$out/api/src/auth.rs" \
      --replace-fail \
        'u::email_is_invalid.eq(true),' \
        'u::email_is_invalid.eq(if config.email.is_some() { Some(true) } else { None }),' \
      --replace-fail \
        $'    {\n        if let Err(e) = make_email' \
        $'    {\n        if config.email.is_none() {\n            return Redirect::to("/");\n        }\n        if let Err(e) = make_email'

    # The database requires repositories.creation_ip, but this clean upstream
    # state accidentally comments the value out of the repository insert.
    substituteInPlace "$out/api/src/settings.rs" \
      --replace-fail \
        '            let repo_id = diesel::insert_into(r::repositories)' \
        $'            let creation_ip =\n                ipnetwork::IpNetwork::new(addr.ip(), if addr.is_ipv4() { 32 } else { 128 })\n                    .unwrap();\n            let repo_id = diesel::insert_into(r::repositories)' \
      --replace-fail \
        '// r::creation_ip.eq(addr.ip()),' \
        'r::creation_ip.eq(&creation_ip),'

    # Keep the initial migration consistent with api/src/db.rs, where this
    # column is PostgreSQL Inet rather than Text.
    substituteInPlace "$out/migrations/2024-11-23-114911_diesel/up.sql" \
      --replace-fail \
        '    creation_ip text not null,' \
        '    creation_ip inet not null,'

    # Several historical handlers hardcode "main" instead of honoring each
    # repository's default_channel. This breaks normal URLs for master-based
    # repositories even though explicit ":master" URLs and SSH pushes work.
    substituteInPlace "$out/api/src/repository/router.rs" \
      --replace-fail \
        $'    let (id, _, _) = super::repository_id(&mut db, &tree.owner, &tree.repo, uid, Perm::READ).await?;\n\n    let c = super::channel_spec_id(id, tree.channel.as_deref().unwrap_or("main"));\n    debug!("channel {:?}", c);\n    let locks = config.repo_locks.clone();\n    let repo_ = locks.get(&id).await.unwrap();\n    let channels = repo_.channels().await;\n    let channel = tree.channel.unwrap_or_else(|| "main".to_string());' \
        $'    let repository = super::repository(\n        &mut db,\n        &tree.owner,\n        &tree.repo,\n        uid.unwrap_or(uuid::Uuid::nil()),\n        Perm::READ,\n    )\n    .await?;\n    let id = repository.id;\n    let default_channel = repository.default_channel;\n    let channel = tree.channel.unwrap_or_else(|| default_channel.clone());\n    let is_default_channel = channel == default_channel;\n    let c = super::channel_spec_id(id, &channel);\n    debug!("channel {:?}", c);\n    let locks = config.repo_locks.clone();\n    let repo_ = locks.get(&id).await.unwrap();\n    let channels = repo_.channels().await;' \
      --replace-fail \
        'txn.channels("")?.is_empty() && channel_ == "main"' \
        'txn.channels("")?.is_empty() && is_default_channel'

    substituteInPlace "$out/api/src/repository/dot_pijul.rs" \
      --replace-fail \
        '    let mut db = config.db.get().await?;' \
        $'    let mut db = config.db.get().await?;\n    let default_channel = super::repository(\n        &mut db,\n        &t.owner,\n        &t.repo,\n        uuid::Uuid::nil(),\n        super::Perm::READ,\n    )\n    .await?\n    .default_channel;' \
      --replace-fail \
        '    let mut channel = ChannelSpec::Channel("main".to_string());' \
        '    let mut channel = ChannelSpec::Channel(default_channel.clone());' \
      --replace-fail \
        '    let is_default_channel = channel == ChannelSpec::Channel("main".to_string());' \
        '    let is_default_channel = channel == ChannelSpec::Channel(default_channel);'

    substituteInPlace "$out/api/src/change/list.rs" \
      --replace-fail \
        $'    let (id, _, _) =\n        crate::repository::repository_id(&mut db, &tree.owner, &tree.repo, uid, Perm::READ).await?;\n\n    let repo_locks = config.repo_locks.clone();\n    let channel_ = tree\n        .channel\n        .as_deref()\n        .unwrap_or_else(|| pijul_core::DEFAULT_CHANNEL)\n        .to_string();' \
        $'    let repository = crate::repository::repository(\n        &mut db,\n        &tree.owner,\n        &tree.repo,\n        uid.unwrap_or(uuid::Uuid::nil()),\n        Perm::READ,\n    )\n    .await?;\n    let id = repository.id;\n    let default_channel = repository.default_channel;\n\n    let repo_locks = config.repo_locks.clone();\n    let channel_ = tree.channel.unwrap_or_else(|| default_channel.clone());' \
      --replace-fail \
        'list_changes(&repo_locks, id, &channel, &req_paths, reverse, from, count).await?;' \
        'list_changes(&repo_locks, id, &channel, &default_channel, &req_paths, reverse, from, count).await?;' \
      --replace-fail \
        $'    channel: &str,\n    req_paths: &[String],' \
        $'    channel: &str,\n    default_channel: &str,\n    req_paths: &[String],' \
      --replace-fail \
        'channel.is_empty() || channel == pijul_core::DEFAULT_CHANNEL' \
        'channel.is_empty() || channel == default_channel'

    substituteInPlace "$out/api/src/change/mod.rs" \
      --replace-fail \
        $'    let (id, _, _) =\n        crate::repository::repository_id(&mut db, &repo.owner, &repo.repo, Some(uid), Perm::APPLY)\n            .await?;' \
        $'    let repository = crate::repository::repository(\n        &mut db,\n        &repo.owner,\n        &repo.repo,\n        uid,\n        Perm::APPLY,\n    )\n    .await?;\n    let id = repository.id;' \
      --replace-fail \
        'channel: repo.channel.clone().unwrap_or_else(|| "main".to_string()),' \
        'channel: repo.channel.clone().unwrap_or(repository.default_channel),'
  '';

  # Nest's generated Cargo.nix expects a current stable Rust toolchain.
  nestPkgs = import inputs.nixpkgs-unpatched {
    inherit system;
    overlays = [ inputs.rust-overlay.overlays.default ];
  };
  buildRustCrate =
    p:
    p.buildRustCrate.override {
      rustc = p.rust-bin.stable.latest.default.override {
        targets = [ "wasm32-unknown-unknown" ];
      };
    };
  crateOverrides = nestPkgs.defaultCrateOverrides // {
    lightningcss = _: {
      features = [ ];
    };
    libsodium-sys = _: {
      nativeBuildInputs = [ nestPkgs.pkg-config ];
      buildInputs = [ nestPkgs.libsodium ];
    };
    etcd-client = _: {
      PROTOC = "${nestPkgs.protobuf}/bin/protoc";
    };
    pq-sys = _: {
      buildInputs = [
        nestPkgs.pkg-config
        nestPkgs.libpq
      ];
      extraLinkFlags = [ "-L${nestPkgs.libpq.out}/lib" ];
    };
    aws-lc-rs = _: {
      buildInputs = [
        nestPkgs.pkg-config
        nestPkgs.aws-lc
      ];
      "DEP_AWS_LC_${nestPkgs.aws-lc.version}_INCLUDE" = "${nestPkgs.aws-lc.dev}/include";
    };
    tikv-jemalloc-sys =
      _:
      let
        jemalloc = nestPkgs.jemalloc.overrideAttrs (
          old:
          old
          // {
            configureFlags = old.configureFlags ++ [
              "--with-jemalloc-prefix=_rjem_"
              "--with-private-namespace=_rjem_"
            ];
          }
        );
      in
      {
        JEMALLOC_OVERRIDE = "${jemalloc}/lib/libjemalloc.so";
      };
  };
  nestWorkspace = nestPkgs.callPackage (nestSource + "/Cargo.nix") {
    buildRustCrateForPkgs = buildRustCrate;
    defaultCrateOverrides = crateOverrides;
  };
  nestApi = nestWorkspace.workspaceMembers.nest.build.override (_: {
    features = [ "jobs" ];
    runTests = false;
  });

  publicHost = "${cfg.domain}:${toString cfg.httpsPort}";
  publicUrl = "https://${publicHost}";
  nestUi = nestPkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "pijul-nest-ui";
    version = "0.0.1";
    src = nestSource + "/ui";

    # This historical UI consumes these through import.meta.env, so they must
    # be set at build time rather than only in the Node service environment.
    VITE_SERVER = publicUrl;
    VITE_LOCAL_SERVER = "http://127.0.0.1:${toString cfg.apiPort}";
    VITE_UI_SERVER = publicUrl;

    nativeBuildInputs = [
      nestPkgs.nodejs
      nestPkgs.pnpmConfigHook
      nestPkgs.pnpm
    ];
    pnpmDeps = nestPkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-yc7hXvI7tii3KJZbUWLj9VHb9/Qci0JruIm0K7+7kJg=";
    };
    # Adapter-node otherwise leaves packages such as s-ago external while the
    # derivation installs only build/, causing runtime module-not-found errors.
    postPatch = ''
      substituteInPlace vite.config.js \
        --replace-fail "const config = {" \
        $'const config = {\n  ssr: { noExternal: true },'
    '';
    preConfigure = "rm -rf node_modules";
    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -r build "$out"
      date -u +%s > "$out/last_modified"
      runHook postInstall
    '';
  });

  dbName = "nest";
  dbUser = "pijul";
  databaseUrl = "postgresql://${dbUser}@/${dbName}?host=/run/postgresql";
  # Match the Unix account to the PostgreSQL role so the server's default
  # local peer authentication works without an hba reload during activation.
  serviceUser = dbUser;
  serviceGroup = "nest";
  secretDir = "${cfg.stateDir}/secrets";
  pbkdf2PasswordFile = "${secretDir}/pbkdf2-password";
  pbkdf2SaltFile = "${secretDir}/pbkdf2-salt";
  tomlString = builtins.toJSON;

  apiConfig = pkgs.writeText "pijul-nest-config.toml" ''
    etcd_server = "127.0.0.1:2379"
    repository_cache_size = 128
    change_cache_size = 128
    max_body_length = 104857600
    hard_max_body_length = 1073741824
    lock_file = ${tomlString "${cfg.stateDir}/lock"}
    repositories_path = ${tomlString "${cfg.stateDir}/repositories"}
    host = ${tomlString publicHost}
    hostname = ${tomlString publicHost}
    origin = ${tomlString publicUrl}
    failed_auth_timeout_millis = 500
    pbkdf2_iterations = 100000
    partial_change_size = 1048576
    max_password_attempts = 20
    pro_prix_euros = 0
    basic_size_limit = 107374182400
    pro_size_limit = 107374182400
    postgres = ${tomlString databaseUrl}

    [time]
    max_relative_days = 2
    yesterday_threshold_hours = 7

    [http]
    http_port = ${toString cfg.apiPort}
    https_port = ${toString cfg.apiAlternatePort}
    ws_port = ${toString cfg.wsPort}
    ws_timeout_secs = 3600
    time_file = ${tomlString "${nestUi}/last_modified"}
    log_file = ${tomlString "${cfg.stateDir}/logs"}
    timeout_secs = 60

    [ssh]
    port = ${toString cfg.sshPort}
    timeout_secs = 120

    [prometheus]
    buckets_start = 0.0
    buckets_width = 10.0
    n_buckets = 50

    [editor]
    port = 4001

    [webauthn]
    rp_origin = ${tomlString publicUrl}
    rp_id = ${tomlString cfg.domain}

    [ci]
    url = []
  '';
  replicationConfig = pkgs.writeText "pijul-nest-replication.toml" ''
    repositories = ${tomlString "${cfg.stateDir}/repositories"}
  '';
  # Diesel 2.3 formats the generated schema differently from the historical
  # source pin. Write that non-runtime artifact to persistent state instead of
  # treating the immutable upstream db.rs as a locked output.
  dieselConfig = pkgs.writeText "pijul-nest-diesel.toml" ''
    [print_schema]
    file = ${tomlString "${cfg.stateDir}/generated-schema.rs"}
    custom_type_derives = ["diesel::query_builder::QueryId"]
    generate_missing_sql_type_definitions = false
    import_types = [
      "diesel::sql_types::*",
      "diesel::pg::sql_types::*",
      "crate::{Keyalgorithm}",
    ]

    [migrations_directory]
    dir = ${tomlString "${nestSource}/migrations"}
  '';
  apiStart = pkgs.writeShellScript "pijul-nest-api-start" ''
    set -euo pipefail
    export ssh_secret="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/ssh-secret")"
    export pbkdf2_password="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/pbkdf2-password")"
    export pbkdf2_salt="$(${pkgs.coreutils}/bin/cat "$CREDENTIALS_DIRECTORY/pbkdf2-salt")"
    exec ${nestApi}/bin/nest \
      --config ${apiConfig} \
      --replication ${replicationConfig}
  '';

  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_read_timeout 3600s;
  '';
in
{
  options.custom_modules.pijul-nest = {
    enable = lib.mkEnableOption "a tailnet-only Pijul Nest forge";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "office-desktop.tail5ca7.ts.net";
      description = "Tailscale hostname used by the Nest web and SSH services";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 7443;
      description = "Tailnet-only HTTPS port for the Nest web interface";
    };

    sshPort = lib.mkOption {
      type = lib.types.port;
      default = 2223;
      description = "Tailnet-only SSH port for Pijul operations";
    };

    nginxPort = lib.mkOption {
      type = lib.types.port;
      default = 8189;
      description = "Loopback nginx port used between Caddy and Nest";
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 5660;
      description = "Internal Nest API HTTP port";
    };

    apiAlternatePort = lib.mkOption {
      type = lib.types.port;
      default = 5661;
      description = "Second internal Nest API HTTP port";
    };

    uiPort = lib.mkOption {
      type = lib.types.port;
      default = 5662;
      description = "Loopback Nest UI port";
    };

    wsPort = lib.mkOption {
      type = lib.types.port;
      default = 5663;
      description = "Internal Nest WebSocket configuration port";
    };

    stateDir = lib.mkOption {
      type = lib.types.strMatching "^/.+";
      default = "/var/lib/pijul-nest";
      description = "Persistent Nest repositories, session secrets, and state";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          lib.length (
            lib.unique [
              cfg.httpsPort
              cfg.sshPort
              cfg.nginxPort
              cfg.apiPort
              cfg.apiAlternatePort
              cfg.uiPort
              cfg.wsPort
            ]
          ) == 7;
        message = "All Pijul Nest ports must be distinct";
      }
    ];

    environment.systemPackages = [ pkgs.pijul ];

    users.groups.${serviceGroup} = { };
    users.users.${serviceUser} = {
      isSystemUser = true;
      group = serviceGroup;
      home = "${cfg.stateDir}/home";
    };

    services.postgresql = {
      ensureDatabases = [ dbName ];
      ensureUsers = [
        {
          name = dbUser;
          # The database is named `nest`, so ownership is assigned explicitly.
          ensureDBOwnership = false;
        }
      ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.stateDir}/home 0750 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.stateDir}/repositories 0750 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.stateDir}/repositories/tmp 0750 ${serviceUser} ${serviceGroup} -"
      "d ${cfg.stateDir}/logs 0750 ${serviceUser} ${serviceGroup} -"
      "d ${secretDir} 0750 root ${serviceGroup} -"
    ];

    systemd.services.pijul-nest-secrets = {
      description = "Create Pijul Nest session secrets";
      before = [ "nest-api.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g ${serviceGroup} ${lib.escapeShellArg secretDir}

        create_secret() {
          local target="$1"
          if [ ! -s "$target" ]; then
            local temporary="$target.tmp"
            ${pkgs.openssl}/bin/openssl rand -base64 48 > "$temporary"
            ${pkgs.coreutils}/bin/install -m 0640 -o root -g ${serviceGroup} "$temporary" "$target"
            ${pkgs.coreutils}/bin/rm -f "$temporary"
          fi
          ${pkgs.coreutils}/bin/chown root:${serviceGroup} "$target"
          ${pkgs.coreutils}/bin/chmod 0640 "$target"
        }

        create_secret ${lib.escapeShellArg pbkdf2PasswordFile}
        create_secret ${lib.escapeShellArg pbkdf2SaltFile}
      '';
    };

    systemd.services.pijul-nest-database = {
      description = "Prepare the Pijul Nest PostgreSQL database";
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      before = [ "nest-api.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        # ensureUsers/ensureDatabases are applied by PostgreSQL's startup hook,
        # which may not run when nixos-rebuild leaves an existing server up.
        # Make service startup independently idempotent as well.
        role_exists="$(${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/psql --dbname=postgres \
          --no-align --tuples-only --set=ON_ERROR_STOP=1 \
          --command=${lib.escapeShellArg "SELECT 1 FROM pg_roles WHERE rolname = '${dbUser}'"})"
        if [ "$role_exists" != "1" ]; then
          ${pkgs.util-linux}/bin/runuser -u postgres -- \
            ${config.services.postgresql.package}/bin/createuser --login ${lib.escapeShellArg dbUser}
        fi

        database_exists="$(${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/psql --dbname=postgres \
          --no-align --tuples-only --set=ON_ERROR_STOP=1 \
          --command=${lib.escapeShellArg "SELECT 1 FROM pg_database WHERE datname = '${dbName}'"})"
        if [ "$database_exists" != "1" ]; then
          ${pkgs.util-linux}/bin/runuser -u postgres -- \
            ${config.services.postgresql.package}/bin/createdb \
            --owner=${lib.escapeShellArg dbUser} ${lib.escapeShellArg dbName}
        fi

        ${pkgs.util-linux}/bin/runuser -u postgres -- \
          ${config.services.postgresql.package}/bin/psql --dbname=postgres \
          --set=ON_ERROR_STOP=1 \
          --command=${lib.escapeShellArg "ALTER DATABASE ${dbName} OWNER TO ${dbUser}"}
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg dbUser} -- \
          ${pkgs.coreutils}/bin/env DATABASE_URL=${lib.escapeShellArg databaseUrl} \
          ${pkgs.diesel-cli}/bin/diesel migration run \
            --migration-dir ${nestSource}/migrations \
            --config-file ${dieselConfig}

        # The pinned clean state originally created this as Text even though
        # the API's Diesel schema uses Inet. Repair already-migrated databases.
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg dbUser} -- \
          ${config.services.postgresql.package}/bin/psql --dbname=${lib.escapeShellArg dbName} \
          --set=ON_ERROR_STOP=1 \
          --command=${lib.escapeShellArg ''
            DO $schema_fix$
            BEGIN
              IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'repositories'
                  AND column_name = 'creation_ip'
                  AND data_type <> 'inet'
              ) THEN
                ALTER TABLE repositories
                  ALTER COLUMN creation_ip TYPE inet USING creation_ip::inet;
              END IF;
            END
            $schema_fix$;
          ''}

        # Accounts created before the no-SMTP registration fix were left in an
        # impossible confirmation state. Activate those pending accounts.
        ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg dbUser} -- \
          ${config.services.postgresql.package}/bin/psql --dbname=${lib.escapeShellArg dbName} \
          --set=ON_ERROR_STOP=1 \
          --command=${lib.escapeShellArg "UPDATE users SET email_is_invalid = NULL WHERE email_is_invalid = TRUE"}
      '';
    };

    systemd.services.nest-api = {
      description = "Pijul Nest API and SSH server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "sshd.service"
        "pijul-nest-database.service"
        "pijul-nest-secrets.service"
      ];
      requires = [
        "pijul-nest-database.service"
        "pijul-nest-secrets.service"
      ];
      environment = {
        DATABASE_URL = databaseUrl;
        HOME = "${cfg.stateDir}/home";
        RUST_BACKTRACE = "1";
        RUST_LOG = "nest=info,ci=info";
      };
      path = [
        pkgs.bash
        pkgs.nix
        pkgs.pijul
      ];
      serviceConfig = {
        ExecStart = apiStart;
        User = serviceUser;
        Group = serviceGroup;
        WorkingDirectory = cfg.stateDir;
        LoadCredential = [
          "ssh-secret:/etc/ssh/ssh_host_ed25519_key"
          "pbkdf2-password:${pbkdf2PasswordFile}"
          "pbkdf2-salt:${pbkdf2SaltFile}"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        Type = "exec";
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.stateDir ];
      };
    };

    systemd.services.nest-ui = {
      description = "Pijul Nest web interface";
      wantedBy = [ "multi-user.target" ];
      after = [ "nest-api.service" ];
      requires = [ "nest-api.service" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString cfg.uiPort;
        ORIGIN = publicUrl;
        NODE_ENV = "production";
      };
      serviceConfig = {
        ExecStart = "${nestPkgs.nodejs}/bin/node ${nestUi}/index.js";
        User = serviceUser;
        Group = serviceGroup;
        WorkingDirectory = cfg.stateDir;
        Restart = "on-failure";
        RestartSec = 5;
        Type = "exec";
        UMask = "0027";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.stateDir ];
      };
    };

    services.nginx = {
      enable = true;
      upstreams.pijul-nest-api.servers."127.0.0.1:${toString cfg.apiPort}" = {
        max_fails = 3;
        fail_timeout = "10s";
      };
      upstreams.pijul-nest-ui.servers."127.0.0.1:${toString cfg.uiPort}" = {
        max_fails = 3;
        fail_timeout = "10s";
      };
      # Use a distinct attribute key so this server block does not merge with
      # the desktop's existing nginx vhost for the same public hostname.
      virtualHosts.pijul-nest-internal = {
        serverName = cfg.domain;
        listen = [
          {
            addr = "127.0.0.1";
            port = cfg.nginxPort;
          }
        ];
        extraConfig = "client_max_body_size 0;";
        locations = {
          "/api" = {
            proxyPass = "http://pijul-nest-api";
            proxyWebsockets = true;
            extraConfig = proxyHeaders;
          };
          "/login" = {
            proxyPass = "http://pijul-nest-api";
            extraConfig = proxyHeaders;
          };
          "/register" = {
            proxyPass = "http://pijul-nest-api";
            extraConfig = proxyHeaders;
          };
          "/recover/reset" = {
            proxyPass = "http://pijul-nest-api";
            extraConfig = proxyHeaders;
          };
          "/logout" = {
            proxyPass = "http://pijul-nest-api";
            extraConfig = proxyHeaders;
          };
          "/identicon" = {
            proxyPass = "http://pijul-nest-api";
            extraConfig = proxyHeaders;
          };
          "~ ^/[^/]+/[^/]+/\\.pijul" = {
            proxyPass = "http://pijul-nest-api";
            proxyWebsockets = true;
            extraConfig = proxyHeaders;
          };
          "/" = {
            proxyPass = "http://pijul-nest-ui";
            proxyWebsockets = true;
            extraConfig = proxyHeaders;
          };
        };
      };
    };

    services.caddy.virtualHosts."${cfg.domain}:${toString cfg.httpsPort}".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString cfg.nginxPort}
    '';

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.httpsPort
      cfg.sshPort
    ];

    services.homepage-dashboard.services = lib.mkAfter [
      {
        "Development" = [
          {
            "Pijul Nest" = {
              icon = "mdi-source-branch";
              href = publicUrl;
              description = "Tailnet-only Pijul forge";
            };
          }
        ];
      }
    ];
  };
}
