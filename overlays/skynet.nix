final: prev:
let
  python = final.python312;
  pythonPackages = final.python312Packages;
in
{
  skynet = pythonPackages.buildPythonApplication rec {
    pname = "skynet";
    version = "2026.5.0";
    pyproject = true;

    src = final.fetchFromGitHub {
      owner = "jitsi";
      repo = "skynet";
      tag = version;
      hash = "sha256-b8fF3eHIuUO0VlU86yN1R0vnjqfA1G+WcE7KbDqcYGg=";
    };

    build-system = with pythonPackages; [ poetry-core ];

    nativeBuildInputs = [ final.makeWrapper ];

    pythonRelaxDeps = true;
    pythonRemoveDeps = [
      "faiss-cpu"
      "flashrank"
      "kreuzberg"
      "langchain"
      "langchain-community"
      "langchain-huggingface"
      "sentence-transformers"
      "silero-vad"
    ];

    postPatch = ''
                  substituteInPlace pyproject.toml \
                    --replace-fail 'python = "~3.11"' 'python = ">=3.11,<3.14"'

            substituteInPlace skynet/modules/ttt/processor.py \
              --replace-fail 'from langchain_classic.retrievers import ContextualCompressionRetriever' "" \
              --replace-fail 'from langchain_community.document_compressors import FlashrankRerank' "" \
              --replace-fail "compressor = FlashrankRerank() if 'assistant' in modules else None" "if 'assistant' in modules:
          from langchain_community.document_compressors import FlashrankRerank
          compressor = FlashrankRerank()
      else:
          compressor = None"
            substituteInPlace skynet/modules/ttt/processor.py \
              --replace-fail '        retriever = ContextualCompressionRetriever(base_compressor=compressor, base_retriever=base_retriever)' '        from langchain_classic.retrievers import ContextualCompressionRetriever

              retriever = ContextualCompressionRetriever(base_compressor=compressor, base_retriever=base_retriever)'

            substituteInPlace skynet/modules/ttt/llm_selector.py \
              --replace-fail 'from langchain_community.chat_models import ChatOCIGenAI' "" \
              --replace-fail '            return ChatOCIGenAI(' '            from langchain_community.chat_models import ChatOCIGenAI

                  return ChatOCIGenAI('

            substituteInPlace skynet/modules/ttt/oci/utils.py \
              --replace-fail 'from langchain_community.chat_models import ChatOCIGenAI' "" \
              --replace-fail '        llm = ChatOCIGenAI(' '        from langchain_community.chat_models import ChatOCIGenAI

              llm = ChatOCIGenAI('

            substituteInPlace skynet/main.py \
              --replace-fail 'port=8001' "port=int(os.environ.get('SKYNET_METRICS_PORT', 8001))"

            substituteInPlace skynet/modules/stt/streaming_whisper/cfg.py \
              --replace-fail "gpu_indices = whisper_gpu_indices.strip().split(',')" "gpu_indices = [int(index.strip()) for index in whisper_gpu_indices.split(',') if index.strip()]"

            substituteInPlace skynet/modules/stt/streaming_whisper/connection_manager.py \
              --replace-fail "                    await connection.ws.send_json(result.model_dump())" "                    log.info(f'Meeting {connection.meeting_id}: sending {result.type} transcription for {result.participant_id}: {result.text[:120]!r}'); await connection.ws.send_json(result.model_dump())"
    '';

    dependencies =
      with pythonPackages;
      [
        aioboto3
        aiofiles
        aiohttp
        async-lru
        av
        beautifulsoup4
        ctranslate2
        einops
        fake-useragent
        fastapi
        fastapi-versionizer
        faster-whisper
        langchain-core
        langchain-openai
        langchain-text-splitters
        oci
        onnxruntime
        openai
        prometheus-client
        prometheus-fastapi-instrumentator
        pybase64
        pydantic
        pyjwt
        pypdf
        python-multipart
        pyyaml
        redis
        torch
        torchaudio
        transformers
        uuid6
        uvicorn
      ]
      ++ pyjwt.optional-dependencies.crypto
      ++ uvicorn.optional-dependencies.standard;

    postInstall = ''
      makeWrapper ${python.interpreter} $out/bin/skynet \
        --add-flags "-m skynet.main" \
        --prefix PYTHONPATH : "$out/${python.sitePackages}:$PYTHONPATH"
    '';

    meta = {
      description = "API server for Jitsi AI services";
      homepage = "https://github.com/jitsi/skynet";
      license = final.lib.licenses.asl20;
      mainProgram = "skynet";
    };
  };
}
