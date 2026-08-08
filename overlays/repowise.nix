{ repowise-src }:

final: prev:
let
  inherit (final) lib;

  pythonGrammarPackages =
    pyFinal: _pyPrev:
    let
      grammarWheel =
        {
          pname,
          version,
          hash,
          url,
          importName ? lib.replaceStrings [ "-" ] [ "_" ] pname,
        }:
        pyFinal.buildPythonPackage rec {
          inherit pname version;
          format = "wheel";

          src = final.fetchurl {
            inherit url hash;
          };

          doCheck = false;
          pythonImportsCheck = [ importName ];
        };
    in
    {
      lancedb = pyFinal.buildPythonPackage rec {
        pname = "lancedb";
        version = "0.30.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/16/68/e01bf7837454a5ce9e2f6773905e07b09a949bc88136c0773c8166ed7729/lancedb-0.30.0-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-CpZ+wF+ZMHcK6wd7xVeXabG+31WfzQOlktlkQIRiWRg=";
        };

        dependencies =
          with pyFinal;
          [
            deprecation
            lance-namespace
            numpy
            packaging
            pyarrow
            pydantic
            tqdm
          ]
          ++ lib.optionals (pythonOlder "3.12") [
            overrides
          ];

        doCheck = false;
        pythonImportsCheck = [ "lancedb" ];
      };

      tree-sitter-cpp = grammarWheel {
        pname = "tree_sitter_cpp";
        version = "0.23.4";
        hash = "sha256-dz0sr8CLvA+Zhof6M/QvN4waNxzbWChwxNE6uwYJJwY=";
        url = "https://files.pythonhosted.org/packages/6a/4d/23e390234d2acd351f5563b1079c515d7c1fe13ddb7392cee543be74dda3/tree_sitter_cpp-0.23.4-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-dart = grammarWheel {
        pname = "tree_sitter_dart";
        version = "0.1.0";
        hash = "sha256-toC83gLRuguXkdCSgEczpRf7O/6bMuACoGIs4ihuYwQ=";
        url = "https://files.pythonhosted.org/packages/10/c9/3dce1e4dc071e8ed536ab30694798fd5d4c7e3a1c875dff60517195bb5bd/tree_sitter_dart-0.1.0-cp38-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      };

      tree-sitter-go = grammarWheel {
        pname = "tree_sitter_go";
        version = "0.25.0";
        hash = "sha256-BLOzy0r/GOdOKNSbcWxvJMtx3f3WZ2iYfibk0PqBL3Q=";
        url = "https://files.pythonhosted.org/packages/86/fb/b30d63a08044115d8b8bd196c6c2ab4325fb8db5757249a4ef0563966e2e/tree_sitter_go-0.25.0-cp310-abi3-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl";
      };

      tree-sitter-java = grammarWheel {
        pname = "tree_sitter_java";
        version = "0.23.5";
        hash = "sha256-NwsgS5UAuEf20MWtWEBFgxzuaemj5Nh4U1055KfkxPE=";
        url = "https://files.pythonhosted.org/packages/29/09/e0d08f5c212062fd046db35c1015a2621c2631bc8b4aae5740d7adb276ad/tree_sitter_java-0.23.5-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-kotlin = grammarWheel {
        pname = "tree_sitter_kotlin";
        version = "1.1.0";
        hash = "sha256-mpKv4ktjTPkUxYEq8PXFMYSxwYvfbuVQXIOvrIH2v2w=";
        url = "https://files.pythonhosted.org/packages/65/bd/0f3aac45eb88b6b3173ac9c23bc41d8865943cbbe1caaafc001cd1b73c90/tree_sitter_kotlin-1.1.0-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-luau = grammarWheel {
        pname = "tree_sitter_luau";
        version = "1.2.0";
        hash = "sha256-e7NeuAjWpR0wqr+ihFvLHM57zmNZm91MH6uk314t+08=";
        url = "https://files.pythonhosted.org/packages/f4/b3/d99f00230812ea2c1c4b53a68de4c38f3c8f7097e898d26cb2e76525d4bb/tree_sitter_luau-1.2.0-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-php = grammarWheel {
        pname = "tree_sitter_php";
        version = "0.24.1";
        hash = "sha256-ehQEow8pckmKzgQLAClzi42sRdChKTLMuLYF65S6++Q=";
        url = "https://files.pythonhosted.org/packages/9a/c6/fd863a7a779d0ab67688939eba0e08bff7b1ffe731288d3d3610df21217b/tree_sitter_php-0.24.1-cp310-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl";
      };

      tree-sitter-ruby = grammarWheel {
        pname = "tree_sitter_ruby";
        version = "0.23.1";
        hash = "sha256-97zZOXK0yigDhW1P4PvQQSP/KcRZK7ufEqJ1KL0lI0E=";
        url = "https://files.pythonhosted.org/packages/23/dd/1171b5dd25da10f768732a20fb62d2e3ae66e3b42329351f2ce5bf723abb/tree_sitter_ruby-0.23.1-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-scala = grammarWheel {
        pname = "tree_sitter_scala";
        version = "0.24.0";
        hash = "sha256-8BOfs69jixBrJADLMKNk5xoPF6BEQCBoumaGyRlHapU=";
        url = "https://files.pythonhosted.org/packages/3f/22/21a75e5cf376e21209b83f8adb993a72668e14f9596d14d13980de837255/tree_sitter_scala-0.24.0-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-svelte = grammarWheel {
        pname = "tree_sitter_svelte";
        version = "1.0.2";
        hash = "sha256-AJcug++aT2wFUyzwYUSIsrQO4Be3fli/jmVA4a3k1S0=";
        url = "https://files.pythonhosted.org/packages/93/48/2fca4934927e1c272e57ca74a599ba773cd4bc52f327c58752a6b01da8d3/tree_sitter_svelte-1.0.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-swift = grammarWheel {
        pname = "tree_sitter_swift";
        version = "0.0.1";
        hash = "sha256-0AnkbZgAz1yjxYUWPQTHBmDROD81Da2T0IvwBzXScUs=";
        url = "https://files.pythonhosted.org/packages/f7/0c/d77ed1d313c4b2360fd7ffa558be796875f400b7eb09efc3373700ffef34/tree_sitter_swift-0.0.1-cp38-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      tree-sitter-typescript = grammarWheel {
        pname = "tree_sitter_typescript";
        version = "0.23.2";
        hash = "sha256-6W02uFvKzeuP9cJhjXVZPvEuuvG06s40d+K9squxdSw=";
        url = "https://files.pythonhosted.org/packages/49/d1/a71c36da6e2b8a4ed5e2970819b86ef13ba77ac40d9e333cb17df6a2c5db/tree_sitter_typescript-0.23.2-cp39-abi3-manylinux_2_5_x86_64.manylinux1_x86_64.manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      };

      sqlglot = pyFinal.buildPythonPackage rec {
        pname = "sqlglot";
        version = "27.29.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/9b/70/20c1912bc0bfebf516d59d618209443b136c58a7cff141afa7cf30969988/sqlglot-27.29.0-py3-none-any.whl";
          hash = "sha256-ml6orGGCandj3hDK1Fo18Kqb/Pe5budK+yMU3pCJ4cs=";
        };

        doCheck = false;
        pythonImportsCheck = [ "sqlglot" ];
      };
    };
in
{
  repowise = final.callPackage (
    {
      python312,
      lib,
    }:

    python312.pkgs.buildPythonApplication rec {
      pname = "repowise";
      version = "0.39.0";
      pyproject = true;

      src = repowise-src;

      postPatch = ''
        python - <<'PY'
        from pathlib import Path

        path = Path("packages/server/src/repowise/server/mcp_server/_server.py")
        source = path.read_text()
        for transport in ("sse", "streamable-http"):
            before = f'        mcp.settings.port = port\n        mcp.run(transport="{transport}")'
            after = f'        mcp.settings.host = os.environ.get("REPOWISE_HOST", "127.0.0.1")\n        mcp.settings.port = port\n        mcp.run(transport="{transport}")'
            if before not in source:
                raise SystemExit(f"expected MCP {transport} port stanza not found")
            source = source.replace(before, after)
        path.write_text(source)
        PY
        substituteInPlace packages/cli/src/repowise/cli/commands/mcp_cmd.py \
          --replace-fail 'URL: http://127.0.0.1:{port}/{endpoint}' 'URL: http://{__import__("os").environ.get("REPOWISE_HOST", "127.0.0.1")}:{port}/{endpoint}'
      '';

      build-system = with python312.pkgs; [ setuptools ];

      dependencies = with python312.pkgs; [
        httpx
        tree-sitter
        tree-sitter-python
        tree-sitter-typescript
        tree-sitter-javascript
        tree-sitter-go
        tree-sitter-rust
        tree-sitter-java
        tree-sitter-cpp
        tree-sitter-dart
        tree-sitter-kotlin
        tree-sitter-ruby
        tree-sitter-c-sharp
        tree-sitter-swift
        tree-sitter-scala
        tree-sitter-php
        tree-sitter-luau
        tree-sitter-bash
        tree-sitter-svelte
        tree-sitter-html
        sqlglot
        networkx
        scipy
        jinja2
        pathspec
        structlog
        sqlalchemy
        aiosqlite
        alembic
        pydantic
        tenacity
        gitpython
        pyyaml
        lancedb
        click
        rich
        watchdog
        fastapi
        uvicorn
        mcp
        apscheduler
        cryptography
        anthropic
        openai
        google-genai
        litellm
      ];

      pythonRelaxDeps = true;

      doCheck = false;
      pythonImportsCheck = [
        "repowise.cli.main"
        "repowise.server.mcp_server"
      ];

      meta = {
        description = "Codebase intelligence layer and MCP server for AI coding agents";
        homepage = "https://github.com/repowise-dev/repowise";
        license = lib.licenses.agpl3Only;
        mainProgram = "repowise";
      };
    }
  ) { };

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    pythonGrammarPackages
  ];
}
