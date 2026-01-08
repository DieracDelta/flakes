# Individual package overrides and custom packages
final: prev: {
  tmuxPlugins = prev.tmuxPlugins // {
    search-panes = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "search-panes";
      version = "0-unstable-2025-04-22";
      src = final.fetchFromGitHub {
        owner = "multi-io";
        repo = "tmux-search-panes";
        rev = "3996b5c56c6be69d3a85ef26065b1877d9ac71c6";
        hash = "sha256-Z9Gu4v2LAyG6UxXVLTvQUz1wU4PaJlBQXjLiSzfSP7s=";
      };
      rtpFilePath = "tmux-search-panes.tmux";
      nativeBuildInputs = [ final.makeWrapper ];
      postInstall = ''
        for f in search-panes.sh _fzf-and-switch.sh _render-preview.sh; do
          chmod +x $target/bin/$f
          wrapProgram $target/bin/$f \
            --prefix PATH : ${
              final.lib.makeBinPath [
                final.coreutils
                final.fzf
                final.gnugrep
                final.gnused
                final.tmux
              ]
            }
        done
      '';
      meta = {
        homepage = "https://github.com/multi-io/tmux-search-panes";
        description = "Tmux plugin for fulltext search across all panes";
        license = final.lib.licenses.mit;
        platforms = final.lib.platforms.unix;
        maintainers = [ final.lib.maintainers.DieracDelta ];
      };
    };
  };
  pam-insults = final.stdenv.mkDerivation {
    pname = "pam-insults";
    version = "unstable-2025-12-19";

    src = final.fetchFromGitHub {
      owner = "cgoesche";
      repo = "pam-insults";
      rev = "2d13ef89640eb57b5e6a64eea080e57d9d936738";
      hash = "sha256-VbEJCO7lvTDKvGpTXQrpgeWEpZE4CMdwaRSuv5shsbw=";
    };

    nativeBuildInputs = [
      final.asciidoctor
      final.gzip
    ];

    buildInputs = [
      final.pam
      final.gettext
    ];

    postPatch = ''
      substituteInPlace Makefile \
        --replace-fail "sudo " "" \
        --replace-fail "mandb" ""
    '';

    makeFlags = [
      "PAM_MODULES_DIR=$(out)/lib/security"
      "MAN_DATABASE=$(out)/share/man/man8"
    ];

    preInstall = ''
      mkdir -p $out/lib/security $out/share/man/man8
    '';

    meta = with final.lib; {
      description = "PAM module that will print an insult to stderr";
      homepage = "https://github.com/cgoesche/pam-insults";
      license = licenses.gpl3Plus;
      platforms = platforms.linux;
    };
  };

  nototools = prev.nototools.overridePythonAttrs (old: {
    dontCheckRuntimeDeps = true;
    catchConflicts = false;
  });

  # Fix dcgm compilation with GCC 15 (missing include and typo)
  dcgm = prev.dcgm.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-fix-gcc15.patch ];
  });

  # Fix dcgm-exporter to find ldconfig in PATH instead of hardcoded /sbin/ldconfig
  prometheus-dcgm-exporter = prev.prometheus-dcgm-exporter.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-exporter-fix-ldconfig.patch ];
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/etc
      cp $src/etc/*.csv $out/etc/
    '';
  });

  # Fix azure-sdk-for-cpp packages with hardcoded sourceRoot
  # See: https://github.com/NixOS/nixpkgs/issues/... (same issue as influxdb2)
  azure-sdk-for-cpp = prev.azure-sdk-for-cpp.overrideScope (azureFinal: azurePrev: {
    core = azurePrev.core.overrideAttrs (finalAttrs: oldAttrs: {
      sourceRoot = "${finalAttrs.src.name}/sdk/core/azure-core";
    });
    identity = azurePrev.identity.overrideAttrs (finalAttrs: oldAttrs: {
      sourceRoot = "${finalAttrs.src.name}/sdk/identity/azure-identity";
    });
    storage-common = azurePrev.storage-common.overrideAttrs (finalAttrs: oldAttrs: {
      sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-common";
    });
    storage-blobs = azurePrev.storage-blobs.overrideAttrs (finalAttrs: oldAttrs: {
      sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-blobs";
    });
    storage-files-datalake = azurePrev.storage-files-datalake.overrideAttrs (finalAttrs: oldAttrs: {
      sourceRoot = "${finalAttrs.src.name}/sdk/storage/azure-storage-files-datalake";
    });
  });
}
