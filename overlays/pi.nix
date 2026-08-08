final: prev: {
  pi-coding-agent = final.buildNpmPackage rec {
    pname = "pi-coding-agent";
    version = "0.83.0";

    src = final.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-${version}-source.tar.gz";
      hash = "sha256-8iW4fsO0gl3VuU6SKoYpVYrdyjGhtNLCBq5Zio4mksA=";
    };

    npmDepsHash = "sha256-AbSfP1Ion8bN309NUBQb1QSn2cIIUjNONmZgls9vnYE=";

    npmWorkspace = "packages/coding-agent";

    npmRebuildFlags = [ "--ignore-scripts" ];

    nativeBuildInputs = [
      final.makeBinaryWrapper
    ];

    buildPhase = ''
      runHook preBuild

      npm run build --workspace=packages/tui
      npm run build:offline --workspace=packages/ai
      npm run build --workspace=packages/agent
      npm run build --workspace=packages/coding-agent

      runHook postBuild
    '';

    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      for ws in @earendil-works/pi-ai:packages/ai \
                @earendil-works/pi-agent-core:packages/agent \
                @earendil-works/pi-tui:packages/tui; do
        IFS=: read -r pkg src <<< "$ws"
        rm "$nm/$pkg"
        cp -r "$src" "$nm/$pkg"
      done

      find "$nm" -type l -lname '*/packages/*' -delete
      find "$nm/.bin" -xtype l -delete
    ''
    + final.lib.optionalString final.stdenvNoCC.hostPlatform.isDarwin ''
      rm -rf \
        "$nm/@anthropic-ai/sandbox-runtime/dist/vendor/seccomp" \
        "$nm/@anthropic-ai/sandbox-runtime/vendor/seccomp"
    '';

    postFixup = ''
      wrapProgram $out/bin/pi --prefix PATH : ${
        final.lib.makeBinPath [
          final.ripgrep
          final.fd
        ]
      } \
        --set-default PI_SKIP_VERSION_CHECK 1 \
        --set-default PI_TELEMETRY 0
    '';

    meta = with final.lib; {
      description = "Coding agent CLI with read, bash, edit, write tools and session management";
      homepage = "https://pi.dev/";
      downloadPage = "https://www.npmjs.com/package/@earendil-works/pi-coding-agent";
      changelog = "https://github.com/earendil-works/pi/blob/main/packages/coding-agent/CHANGELOG.md";
      license = licenses.mit;
      mainProgram = "pi";
    };
  };

  pi-mcp-adapter = final.buildNpmPackage rec {
    pname = "pi-mcp-adapter";
    version = "2.20.1";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/pi-mcp-adapter/-/pi-mcp-adapter-${version}.tgz";
      hash = "sha512-bBna74NHM/YXHE2wYgA4atXD9XTPqHhTVS4f6TLYstWNgXUZyuegaTuM07oeAIYjZE3xPvBn0Wl71bSdUSTQVg==";
    };

    npmDepsHash = "sha256-+zbY3TX5dfJxSuU+TBGt7Xncebi6f8bMN3zG1ocVvmE=";

    postPatch = ''
      # Node is not available while buildNpmPackage constructs the fixed-output
      # dependency cache, so remove development dependencies with shell tools.
      sed -i '/^  "devDependencies": {$/,$d' package.json
      sed -i '$s/,$//' package.json
      printf '}\n' >> package.json
      cp ${./pi-mcp-adapter-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/pi-mcp-adapter"
      cp -R . "$out/lib/node_modules/pi-mcp-adapter"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "MCP adapter extension for Pi coding agent";
      homepage = "https://github.com/nicobailon/pi-mcp-adapter";
      license = licenses.mit;
      mainProgram = "pi-mcp-adapter";
    };
  };

  pi-subagents = final.buildNpmPackage rec {
    pname = "pi-subagents";
    version = "0.14.3";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/@tintinweb/pi-subagents/-/pi-subagents-${version}.tgz";
      hash = "sha512-iDqeadh6114AZvw8HYe1PEq8M0MZ9czJKTAIsklCPUbV9vUMS+g/LAV0vW3O9PiBXKNJh8hkrY8L6iIr8XNEqA==";
    };

    npmDepsHash = "sha256-8J0iPuc4h6mBqfRopmU180+3b/I5JT1ucJVXFvyBapk=";

    npmFlags = [
      "--legacy-peer-deps"
      "--omit=dev"
    ];

    postPatch = ''
      cp ${./pi-subagents-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/@tintinweb/pi-subagents"
      cp -R . "$out/lib/node_modules/@tintinweb/pi-subagents"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Claude Code-style autonomous sub-agents extension for Pi";
      homepage = "https://github.com/tintinweb/pi-subagents";
      license = licenses.mit;
    };
  };

  pi-background-tasks = final.buildNpmPackage rec {
    pname = "pi-background-tasks";
    version = "2.0.0";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/pi-background-tasks/-/pi-background-tasks-${version}.tgz";
      hash = "sha512-LyTFnuPbL2BhzNQaq7l7KN3neV2WyQbH1uEiSTM4cpyAw7489SATqQDoZ9SCqkRIBH/zktP7xvk/VNerpU3QPQ==";
    };

    npmDepsHash = "sha256-++1/PtmRA5TxUg4lMxbQ3ipOC/3PD0zWAqbaMXFH1Rg=";

    npmFlags = [
      "--legacy-peer-deps"
      "--omit=dev"
    ];

    postPatch = ''
      sed -i '/  "devDependencies": {/,/^  },$/d' package.json
      cp ${./pi-background-tasks-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/pi-background-tasks"
      cp -R . "$out/lib/node_modules/pi-background-tasks"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Durable background tasks, delegated agents, and multi-model Fusion workflows for Pi";
      homepage = "https://pi.dev/packages/pi-background-tasks";
      license = licenses.isc;
    };
  };

  pi-codex-goal = final.buildNpmPackage rec {
    pname = "pi-codex-goal";
    version = "0.1.39";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/pi-codex-goal/-/pi-codex-goal-${version}.tgz";
      hash = "sha512-OHV5hPmpP3MB5MsbpujUkCN3KjjncXl82RX9aL87EZaPYefxs9oHqCbA9+BdYX3D508yFjK+CQlvl5LMi2J5fw==";
    };

    npmDepsHash = "sha256-J6DPNHI3z+0R12ZuXAZo+wuqfeGO4lXL547yQs3eNU8=";
    npmDepsFetcherVersion = 2;

    npmFlags = [ "--legacy-peer-deps" ];

    postPatch = ''
      cp ${./pi-codex-goal-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/pi-codex-goal"
      cp -R . "$out/lib/node_modules/pi-codex-goal"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Codex-style goal tracking and continuation for Pi";
      homepage = "https://github.com/fitchmultz/pi-codex-goal";
      license = licenses.mit;
    };
  };

  pi-web-access = final.buildNpmPackage rec {
    pname = "pi-web-access";
    version = "0.18.0";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/pi-web-access/-/pi-web-access-${version}.tgz";
      hash = "sha512-UVLWaNBHrbbe2jnpYq+uVJdPgoExz8HevkI7r3VSboZ6AT/S7oxsxpJY/a72mUt9jAy41512ndVxfxh/CIuYqg==";
    };

    npmDepsHash = "sha256-oV3Iz6e9jvKvjx9Sp/qplL6wqpQ4EkJBAyDZhq145l4=";

    npmFlags = [
      "--legacy-peer-deps"
      "--omit=dev"
    ];

    postPatch = ''
      cp ${./pi-web-access-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/pi-web-access"
      cp -R . "$out/lib/node_modules/pi-web-access"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Web search, URL fetching, GitHub repo cloning, PDF extraction, and video understanding for Pi";
      homepage = "https://github.com/nicobailon/pi-web-access";
      license = licenses.mit;
    };
  };

  context-mode = final.buildNpmPackage rec {
    pname = "context-mode";
    version = "1.0.169";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
      hash = "sha512-94JIaFuLjF9SO2BsGTrbGtyT44K95+9OC8BdbaL/UT76xOkanJLfUR5CzmNw+GELXZQqH4nBrKg9wjBnSFkVnQ==";
    };

    npmDepsHash = "sha256-jwCimDVJXiCVQ2oWZMKoZtwi8DA3rB8KqvJe9C8eudA=";

    npmFlags = [
      "--legacy-peer-deps"
      "--omit=dev"
    ];

    nativeBuildInputs = [
      final.makeBinaryWrapper
      final.python3
      final.pkg-config
    ];

    postPatch = ''
      cp ${./context-mode-package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/node_modules/context-mode" "$out/bin"
      cp -R . "$out/lib/node_modules/context-mode"
      chmod +x "$out/lib/node_modules/context-mode/cli.bundle.mjs"
      makeWrapper "$out/lib/node_modules/context-mode/cli.bundle.mjs" "$out/bin/context-mode" \
        --prefix PATH : ${final.lib.makeBinPath [ final.nodejs ]}

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Token-efficient context management for coding agents";
      homepage = "https://pi.dev/packages/context-mode";
      license = licenses.mit;
      mainProgram = "context-mode";
    };
  };
}
