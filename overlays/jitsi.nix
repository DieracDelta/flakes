final: prev:
let
  jitsiMeetVersion = "1.0.11146";
  opensslLib = "${final.openssl.out}/lib";
  rawJitsiMeetSrc = final.fetchFromGitHub {
    owner = "jitsi";
    repo = "jitsi-meet";
    tag = "jitsi-meet_11146";
    hash = "sha256-gAXY40jvQjGhitbpWjJ+C8GZwuRu/zyJw2NN5yf/l6o=";
  };

  jitsiMeetSrcNoOlm =
    final.runCommand "jitsi-meet-${jitsiMeetVersion}-src-no-olm"
      {
        nativeBuildInputs = [
          final.jq
          final.gnused
          final.perl
        ];
      }
      ''
            cp -R --no-preserve=mode,ownership ${rawJitsiMeetSrc} $out
            chmod -R u+w $out

            jq 'del(.dependencies["@matrix-org/olm"])' \
              $out/package.json > $out/package.json.tmp
            mv $out/package.json.tmp $out/package.json

            jq '
              del(.packages[""].dependencies["@matrix-org/olm"])
              | del(.packages["node_modules/@matrix-org/olm"])
              | del(.dependencies["@matrix-org/olm"])
            ' $out/package-lock.json > $out/package-lock.json.tmp
            mv $out/package-lock.json.tmp $out/package-lock.json

            sed -i "/^import '@matrix-org\/olm';$/d" $out/app.js
            perl -0pi -e 's#// Initialize Olm as early as possible\.\nif \(window\.Olm\) \{.*?\n\}\n\n##s' $out/app.js

            perl -0pi -e 's#^OLM_DIR = node_modules/\@matrix-org/olm\n##m; s# deploy-olm##g; s#\ndeploy-olm:\n\tcp \\\\\n\t\t\$\(OLM_DIR\)/olm\.wasm \\\\\n\t\t\$\(DEPLOY_DIR\)\n##s' $out/Makefile
            sed -i '/^deploy-olm:$/,+3d' $out/Makefile
            substituteInPlace $out/index.html \
              --replace-fail "const shouldRegisterWorker = !isElectron && !isEmbedded() && 'serviceWorker' in navigator;" "const shouldRegisterWorker = false;"

            substituteInPlace $out/react/features/transcribing/functions.ts \
              --replace-fail "import { isJwtFeatureEnabled } from '../base/jwt/functions';" "import { isJwtFeatureEnabled } from '../base/jwt/functions';
        import { isLocalParticipantModerator } from '../base/participants/functions';" \
              --replace-fail "const isTranscribingAllowed = isJwtFeatureEnabled(state, MEET_FEATURES.TRANSCRIPTION, false);" "const isTranscribingAllowed = isJwtFeatureEnabled(state, MEET_FEATURES.TRANSCRIPTION, false) || isLocalParticipantModerator(state);"

            substituteInPlace $out/react/features/subtitles/middleware.ts \
              --replace-fail "import { TRANSCRIBER_ID } from '../base/participants/constants';" "import { TRANSCRIBER_ID } from '../base/participants/constants';
        import { isLocalParticipantModerator } from '../base/participants/functions';" \
              --replace-fail "        if (!action.participant.isHidden()) {
                    return next(action);
                }
                json = action.data;" "        json = action.data;
                if (!action.participant.isHidden()
                    && ![ JSON_TYPE_TRANSCRIPTION_RESULT, JSON_TYPE_TRANSLATION_RESULT ].includes(json?.type)) {
                    return next(action);
                }" \
              --replace-fail "} else if (action.type === NON_PARTICIPANT_MESSAGE_RECEIVED && action.id === TRANSCRIBER_ID) {
                json = action.json;
            } else {" "} else if (action.type === NON_PARTICIPANT_MESSAGE_RECEIVED
                    && (action.id === TRANSCRIBER_ID
                        || [ JSON_TYPE_TRANSCRIPTION_RESULT, JSON_TYPE_TRANSLATION_RESULT ].includes(action.json?.type))) {
                json = action.json;
            } else {" \
              --replace-fail "&& isJwtFeatureEnabled(getState(), MEET_FEATURES.TRANSCRIPTION, false)) {" "&& (isJwtFeatureEnabled(getState(), MEET_FEATURES.TRANSCRIPTION, false) || isLocalParticipantModerator(getState()))) {"

            # Current upstream already treats an unset selected translation language as
            # the original transcription language, so the old language guard is dropped.

            substituteInPlace $out/react/features/base/settings/reducer.ts \
              --replace-fail "showSubtitlesOnStage: false," "showSubtitlesOnStage: true,"
      '';
in
{
  jigasi = (prev.jigasi.override { jdk11 = final.temurin-bin-11; }).overrideAttrs (old: rec {
    version = "1.1-412-ge9a3acc";
    src = final.fetchurl {
      url = "https://download.jitsi.org/stable/jigasi_${version}-1_all.deb";
      hash = "sha256-NlJxfUyUGUqyk8rQAtykZhyAhMapmTvca42HaG1MRJU=";
    };

    postFixup = (old.postFixup or "") + ''
      substituteInPlace $out/bin/jigasi \
        --replace-fail 'LD_LIBRARY_PATH=$libs exec' 'LD_LIBRARY_PATH=$libs:${opensslLib} exec' \
        --replace-fail '-Djava.library.path=$libs' '-Djava.library.path=$libs:${opensslLib}'
    '';
  });

  jitsi-meet = prev.jitsi-meet.overrideAttrs (old: rec {
    version = jitsiMeetVersion;
    src = jitsiMeetSrcNoOlm;

    env = (old.env or { }) // {
      forceGitDeps = "1";
      npmDeps = final.fetchNpmDeps {
        inherit src;
        forceGitDeps = true;
        hash = "sha256-ivB6BBbI86e/7wBpXPcE6g9/jS7klMkp8Sj8IxT1tzE=";
      };
    };

    meta = (old.meta or { }) // {
      knownVulnerabilities = [ ];
    };
  });
}
