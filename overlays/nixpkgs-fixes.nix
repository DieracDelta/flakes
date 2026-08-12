# Temporary fixes for regressions in the locked nixpkgs revision. Keep these
# narrow and remove each override when its matching upstream patch lands.
final: prev:
let
  nixStaticPkgconfigDeps = [
    final.brotli
    final.curl
    final.editline
    final.libblake3
    final.libcpuid
    final.libgit2
    final.libseccomp
    final.libsodium
    final.lowdown
    final.openssl
    final.sqlite
  ];

  fixOllamaSourceRoot =
    drv:
    drv.overrideAttrs (old: {
      # nixpkgs' postPatch assumes fetchFromGitHub unpacks to
      # $NIX_BUILD_TOP/source, but current source names are release-specific.
      # Capture the real source root before the llama.cpp subshell changes $PWD.
      postPatch =
        ''
          ollamaCompatDir=$PWD/llama/compat
        ''
        + builtins.replaceStrings
          [ "$NIX_BUILD_TOP/source/llama/compat" ]
          [ "$ollamaCompatDir" ]
          old.postPatch;
    });
in
{
  ollama = fixOllamaSourceRoot prev.ollama;
  ollama-cuda = fixOllamaSourceRoot prev.ollama-cuda;

  # Nix 2.31's static nix-util pkg-config metadata has private dependencies
  # that the Haskell binding does not declare. Keep the repair inside Cachix's
  # Haskell scope so unrelated packages do not acquire a second package set.
  cachix = prev.cachix.override {
    haskellPackages = prev.haskellPackages.extend (
      _haskellFinal: haskellPrev: {
        cachix = prev.haskell.lib.addPkgconfigDepends haskellPrev.cachix nixStaticPkgconfigDeps;
        hercules-ci-cnix-store = prev.haskell.lib.addPkgconfigDepends (
          haskellPrev.hercules-ci-cnix-store
        ) nixStaticPkgconfigDeps;
      }
    );
  };

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pythonFinal: pythonPrev: {
      # These dependencies became mandatory in upstream release metadata, but
      # the corresponding nixpkgs updates left them in nativeCheckInputs or
      # omitted them. Test inputs masked the defects until checks were disabled.
      autobahn = pythonPrev.autobahn.overridePythonAttrs (old: {
        dependencies = (old.dependencies or [ ]) ++ [
          pythonFinal.cbor2
          pythonFinal.cffi
          pythonFinal.msgpack
          pythonFinal.py-ubjson
          pythonFinal.ujson
        ];
        optional-dependencies = old.optional-dependencies // {
          serialization = [ ];
        };
      });

      opentelemetry-exporter-otlp-proto-grpc =
        pythonPrev.opentelemetry-exporter-otlp-proto-grpc.overridePythonAttrs
          (old: {
            dependencies = (old.dependencies or [ ]) ++ [ pythonFinal.opentelemetry-sdk ];
          });

      opentelemetry-instrumentation = pythonPrev.opentelemetry-instrumentation.overridePythonAttrs (
        old: {
          dependencies =
            (old.dependencies or [ ])
            ++ [ pythonFinal.opentelemetry-semantic-conventions ];
        }
      );

      opentelemetry-util-http = pythonPrev.opentelemetry-util-http.overridePythonAttrs (old: {
        dependencies =
          (old.dependencies or [ ])
          ++ [ pythonFinal.opentelemetry-semantic-conventions ];
      });

      sse-starlette = pythonPrev.sse-starlette.overridePythonAttrs (old: {
        dependencies = (old.dependencies or [ ]) ++ [ pythonFinal.starlette ];
      });
    })
  ];
}
