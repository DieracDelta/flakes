# amp-cli overlay — bump to latest npm version
final: prev: {
  amp-cli = final.buildNpmPackage rec {
    pname = "amp-cli";
    version = "0.0.1772725772-g52e1a8";

    src = final.fetchzip {
      url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
      hash = "sha256-UrfkZG2qUok2OoKbMjtAYTfBEtKp0LtaozrW67HW+1k=";
    };

    postPatch = ''
      cp ${./amp-cli-package-lock.json} package-lock.json

      cat > package.json <<EOF
      {
        "name": "amp-cli",
        "version": "0.0.0",
        "license": "UNLICENSED",
        "dependencies": {
          "@sourcegraph/amp": "${version}"
        },
        "bin": {
          "amp": "./bin/amp-wrapper.js"
        }
      }
      EOF

      mkdir -p bin

      cat > bin/amp-wrapper.js << EOF
      #!/usr/bin/env node
      import('@sourcegraph/amp/dist/main.js')
      EOF
      chmod +x bin/amp-wrapper.js
    '';

    npmDepsHash = "sha256-5+f90fasxq7wwKWyHmN3VgntEm66V1TFrJ4Cyqn92BY=";

    propagatedBuildInputs = [ final.ripgrep ];
    nativeBuildInputs = [ final.makeWrapper ];

    npmFlags = [ "--no-audit" "--no-fund" "--ignore-scripts" ];
    dontNpmBuild = true;

    postInstall = ''
      wrapProgram $out/bin/amp \
        --prefix PATH : ${final.lib.makeBinPath [ final.ripgrep ]} \
        --set AMP_SKIP_UPDATE_CHECK 1
    '';

    meta = with final.lib; {
      description = "CLI for Amp, an agentic coding agent in research preview from Sourcegraph";
      homepage = "https://ampcode.com/";
      license = licenses.unfree;
      mainProgram = "amp";
    };
  };
}
