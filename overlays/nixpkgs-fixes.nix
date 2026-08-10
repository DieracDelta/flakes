# Temporary fixes for regressions in the locked nixpkgs revision. Keep these
# narrow and remove each override when its matching upstream patch lands.
final: prev:
let
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

  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pythonFinal: pythonPrev: {
      # These dependencies became mandatory in upstream release metadata, but
      # the corresponding nixpkgs updates left them in nativeCheckInputs or
      # omitted them. Test inputs masked the defects until checks were disabled.
      autobahn = pythonPrev.autobahn.overridePythonAttrs (old: {
        dependencies = (old.dependencies or [ ]) ++ [
          pythonFinal.cbor2
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
