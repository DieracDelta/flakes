# mcp-remote overlay
# Packages mcp-remote from npm tarball with reproducible source + npm deps hashes.
final: _:
let
  version = "0.1.38";
in
{
  mcp-remote = final.buildNpmPackage {
    pname = "mcp-remote";
    inherit version;

    src = final.fetchurl {
      url = "https://registry.npmjs.org/mcp-remote/-/mcp-remote-${version}.tgz";
      hash = "sha256-2OcDTtTd8fG179kot05xZatCf3shq4bOeby4Kk2VYKo=";
    };

    sourceRoot = "package";
    npmDepsHash = "sha256-R+r6jcXIVCF5NjsiCCvwIeE+qGXXWGTZULK9NdCZid0=";
    nodejs = final.nodejs_22;
    dontNpmBuild = true;

    postPatch = ''
      cp ${./mcp-remote-package-lock.json} package-lock.json
    '';

    nativeBuildInputs = [ final.makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/mcp-remote $out/bin
      cp -r dist package.json README.md LICENSE node_modules $out/lib/mcp-remote/

      makeWrapper ${final.nodejs_22}/bin/node $out/bin/mcp-remote \
        --add-flags "$out/lib/mcp-remote/dist/proxy.js"

      makeWrapper ${final.nodejs_22}/bin/node $out/bin/mcp-remote-client \
        --add-flags "$out/lib/mcp-remote/dist/client.js"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Remote proxy for MCP clients to connect to remote servers with OAuth";
      homepage = "https://github.com/geelen/mcp-remote";
      license = licenses.mit;
      platforms = platforms.unix;
      mainProgram = "mcp-remote";
    };
  };
}
