# Individual package overrides and custom packages
_: final: prev:
let
  # Import shared tmux-search-panes overlay
  tmuxOverlay = import ./tmux-search-panes.nix { } final prev;

  # AudioMuse-AI pins onnxruntime-gpu 1.19.2 upstream. nixpkgs currently
  # provides a newer CUDA-enabled onnxruntime.
  onnxruntimeGpuFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "onnxruntime-gpu";
      version = "1.19.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/68/55/49e5b4b4d6e9a8841dcdec2f102069716b626bf6ce9640b832a9497504eb/onnxruntime_gpu-1.19.2-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-VUoCo/rAEZcH64cyeQiv0hxObw+lv5oDQ5jwmK3DFsU=";
      };

      nativeBuildInputs = [
        final.autoPatchelfHook
        final.patchelf
      ];
      autoPatchelfIgnoreMissingDeps = [
        "libnvinfer.so.10"
        "libnvinfer_plugin.so.10"
        "libnvonnxparser.so.10"
      ];
      appendRunpaths = [
        "${placeholder "out"}/lib/python3.12/site-packages/onnxruntime/capi"
      ];

      buildInputs = [
        final.stdenv.cc.cc.lib
        final.cudaPackages.cuda_cudart
        final.cudaPackages.cuda_cupti
        final.cudaPackages.cuda_nvrtc
        final.cudaPackages.cudnn
        final.cudaPackages.libcublas
        final.cudaPackages.libcufft
        final.cudaPackages.libcurand
        final.cudaPackages.libcusolver
        final.cudaPackages.libcusparse
        final.cudaPackages.nccl
      ];

      propagatedBuildInputs = with ps; [
        coloredlogs
        flatbuffers
        numpy
        packaging
        protobuf
        sympy
      ];

      pythonImportsCheck = [ "onnxruntime" ];

      meta = with final.lib; {
        description = "ONNX Runtime GPU Python wheel pinned for AudioMuse-AI";
        homepage = "https://onnxruntime.ai/";
        license = licenses.mit;
      };
    };

  scipyPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "scipy";
      version = "1.16.3";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/79/2e/415119c9ab3e62249e18c2b082c07aff907a273741b3f8160414b0e9193c/scipy-1.16.3-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
        hash = "sha256-ctFxf9O15ux0cyfOm9oy1UY/Ryydzp9USZ6B+9UCRaE=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.gfortran.cc.lib
        final.zlib
      ];
      propagatedBuildInputs = [ ps.numpy ];
      pythonImportsCheck = [ "scipy" ];
    };

  llvmlitePinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "llvmlite";
      version = "0.43.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/00/5f/323c4d56e8401c50185fd0e875fcf06b71bf825a863699be1eb10aa2a9cb/llvmlite-0.43.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-32UJ4VB8oHYHh6GZ0ZQ5zIh7/YIib1r3RtaXe9n2aEQ=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.tbb
        final.zlib
      ];
      pythonImportsCheck = [ "llvmlite" ];
    };

  numbaPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "numba";
      version = "0.60.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/8b/41/ac11cf33524def12aa5bd698226ae196a1185831c05ed29dc0c56eaa308b/numba-0.60.0-cp312-cp312-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
        hash = "sha256-DrqpFTjplvcI8asw70093DRLZLUie2eleqdPQBu2i50=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.tbb
        final.zlib
      ];
      propagatedBuildInputs = with ps; [
        llvmlite
        numpy
      ];
      pythonImportsCheck = [ "numba" ];
    };

  mlDtypesPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "ml_dtypes";
      version = "0.5.4";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/3a/cb/28ce52eb94390dda42599c98ea0204d74799e4d8047a0eb559b6fd648056/ml_dtypes-0.5.4-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-mtRZ6ZeT+m4TvVt+Z5LI+RkLTlobRcY6uhSk0Kfx1f8=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.tbb
        final.zlib
      ];
      propagatedBuildInputs = [ ps.numpy ];
      pythonImportsCheck = [ "ml_dtypes" ];
    };

  onnxPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "onnx";
      version = "1.22.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/09/a6/bd32357e6cc1ecb473afd78193d7231724f284435d2db25696ecfaaa1503/onnx-1.22.0-cp312-abi3-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-lV4C4fbThbU9UvnNe5zfXK9BfDALz+PGTG1UK+djhFs=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.zlib
      ];
      propagatedBuildInputs = with ps; [
        ml-dtypes
        numpy
        protobuf
        typing-extensions
      ];
      pythonImportsCheck = [ "onnx" ];
    };

  avPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "av";
      version = "13.1.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/7f/22/0dd8d1d5cad415772bb707d16aea8b81cf75d340d11d3668eea43468c730/av-13.1.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-2KrsLAv9AkNZ2zgh1nkAnU5jfhvuAyHSD2HFTtayD0E=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.zlib
      ];
      pythonImportsCheck = [ "av" ];
    };

  stopwordsPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "stopwords";
      version = "1.0.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/83/39/a4b6e68ba1df2848a28b195ae32626b7a4ae6fb3fd156c078cfdad3ab1dd/stopwords-1.0.2-py2.py3-none-any.whl";
        hash = "sha256-ng327dFmQBG3d19ItBY88cdB4wEQVt4rKccdYopzMbE=";
      };

      pythonImportsCheck = [ "stopwords" ];
    };

  huggingfaceHubPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "huggingface-hub";
      version = "0.36.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/a8/af/48ac8483240de756d2438c380746e7130d1c6f75802ef22f3c6d49982787/huggingface_hub-0.36.2-py3-none-any.whl";
        hash = "sha256-SPDI6sFhRd/ONx6dLXdyhUpPWRvLVsnPVIrM9THVQnA=";
      };

      propagatedBuildInputs = with ps; [
        filelock
        fsspec
        hf-xet
        packaging
        pyyaml
        requests
        tqdm
        typing-extensions
      ];
      pythonImportsCheck = [ "huggingface_hub" ];
    };

  transformersPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "transformers";
      version = "4.57.6";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/03/b8/e484ef633af3887baeeb4b6ad12743363af7cce68ae51e938e00aaa0529d/transformers-4.57.6-py3-none-any.whl";
        hash = "sha256-TJ6d4RMz3f5RFLyHLJ83BQkZis8Lh6gyoKuUWOK9BVA=";
      };

      propagatedBuildInputs = with ps; [
        filelock
        huggingface-hub
        numpy
        packaging
        pyyaml
        regex
        requests
        safetensors
        tokenizers
        tqdm
      ];
      pythonImportsCheck = [ "transformers" ];
    };

  hfXetPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "hf-xet";
      version = "1.2.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/9a/92/cf3ab0b652b082e66876d08da57fcc6fa2f0e6c70dfbbafbd470bb73eb47/hf_xet-1.2.0-cp37-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-NlH9W/4CgZUbmIwPrL5yaqXjR7EDpnX0mj+oFEx5aP0=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [ final.stdenv.cc.cc.lib ];
      pythonImportsCheck = [ "hf_xet" ];
    };

  tokenizersPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "tokenizers";
      version = "0.22.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/2e/76/932be4b50ef6ccedf9d3c6639b056a967a86258c6d9200643f01269211ca/tokenizers-0.22.2-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-NpzJ/IzBDLJBQ4c6DZVDi7juJXu4DHGYnj7ikOjXLGc=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [ final.stdenv.cc.cc.lib ];
      propagatedBuildInputs = [ ps.huggingface-hub ];
      pythonImportsCheck = [ "tokenizers" ];
    };

  safetensorsPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "safetensors";
      version = "0.7.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/a0/60/429e9b1cb3fc651937727befe258ea24122d9663e4d5709a48c9cbfceecb/safetensors-0.7.0-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
        hash = "sha256-2sclKTjwaW3epG9ehV3TE4RE6CI2475HX1SSnwxRDUg=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [ final.stdenv.cc.cc.lib ];
      pythonImportsCheck = [ "safetensors" ];
    };

  rapidsCudaBuildInputs = [
    final.stdenv.cc.cc.lib
    final.numactl
    final.zlib
    final.cudaPackages.cuda_cudart
    final.cudaPackages.cuda_cupti
    final.cudaPackages.cuda_nvrtc
    final.cudaPackages.libcublas
    final.cudaPackages.libcufft
    final.cudaPackages.libcurand
    final.cudaPackages.libcusolver
    final.cudaPackages.libcusparse
    final.cudaPackages.libnvjitlink
    final.cudaPackages.nccl
  ];

  rapidsWheelDefaults = {
    nativeBuildInputs = [ final.autoPatchelfHook ];
    buildInputs = rapidsCudaBuildInputs;
    autoPatchelfIgnoreMissingDeps = [
      "libcuda.so.1"
      "libnvidia-ml.so.1"
      "libcudnn.so.8"
      "libcutensor.so.2"
    ];
    dontCheckRuntimeDeps = true;
  };

  cudaPythonPinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "cuda-python";
        version = "12.6.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/e7/15/f2e6cd28c5523c638ebd704c3268abb60e684506c1f4813e3dd4dcad167f/cuda_python-12.6.0-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-63VaCCXEL/ddaxE8hSs7mrWA8abN5MsZtX0ElZJc1cw=";
        };

        pythonImportsCheck = [ "cuda" ];
      }
    );

  cupyCuda12xPinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "cupy-cuda12x";
        version = "13.6.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/e0/95/d7e1295141e7d530674a3cc567e13ed0eb6b81524cb122d797ed996b5bea/cupy_cuda12x-13.6.0-cp312-cp312-manylinux2014_x86_64.whl";
          hash = "sha256-ebDKy16LGQ70CfngPwasjeGwIbDA3aR2dNRG9VV+DrE=";
        };

        propagatedBuildInputs = with ps; [
          fastrlock
          numpy
        ];
        pythonImportsCheck = [ "cupy" ];
      }
    );

  rmmCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "rmm-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/14/31/4d5a9dda6918386caddf1d40cddbf1611bdf81f1a9365cd9c2b3e655ca09/rmm_cu12-24.12.0-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-e3nkUimz8m5xWQOBqOlc2Uf3CqdUM7t963xAg6mVOvo=";
        };

        propagatedBuildInputs = with ps; [
          cuda-python
          numba
          numpy
        ];
        pythonImportsCheck = [ "rmm" ];
      }
    );

  pylibraftCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "pylibraft-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://pypi.nvidia.com/pylibraft-cu12/pylibraft_cu12-24.12.0-cp312-cp312-manylinux_2_28_x86_64.whl";
          hash = "sha256-KRuAS6IcNLurF9o01sxu6GuXUPJxTfvTOcWQb++3IB4=";
        };

        propagatedBuildInputs = with ps; [
          cuda-python
          numpy
          rmm
        ];
        pythonImportsCheck = [ "pylibraft" ];
      }
    );

  cuvsCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "cuvs-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://pypi.nvidia.com/cuvs-cu12/cuvs_cu12-24.12.0-cp312-cp312-manylinux_2_28_x86_64.whl";
          hash = "sha256-xgnG6pkB4uaLhnscelH7kCDHnrHh/r8af7iH1a1GS6I=";
        };

        propagatedBuildInputs = with ps; [
          cuda-python
          numpy
          pylibraft
        ];
        pythonImportsCheck = [ "cuvs" ];
      }
    );

  treelitePinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "treelite";
        version = "4.3.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/42/0e/c9aecfed527ef6bff91ea51036cfcf4b6f6218bc6f507cdf4dff0bb2c81f/treelite-4.3.0-py3-none-manylinux2014_x86_64.whl";
          hash = "sha256-MubAl5bRHwEHrcNYl9hfJcdK0uU+Bmbff7v1fx1UWx8=";
        };

        propagatedBuildInputs = with ps; [
          numpy
          packaging
          scipy
        ];
        pythonImportsCheck = [ "treelite" ];
      }
    );

  pandasPinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "pandas";
        version = "2.2.3";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/38/f8/d8fddee9ed0d0c0f4a2132c1dfcf0e3e53265055da8df952a53e7eaf178c/pandas-2.2.3-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-//uK542K+X+ElATyFBHJUGLbFJaus+VvFG8DVcmYkxk=";
        };

        propagatedBuildInputs = with ps; [
          numpy
          python-dateutil
          pytz
          tzdata
        ];
        pythonImportsCheck = [ "pandas" ];
      }
    );

  pyarrowPinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "pyarrow";
        version = "18.1.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/3a/2e/3b99f8a3d9e0ccae0e961978a0d0089b25fb46ebbcfb5ebae3cca179a5b3/pyarrow-18.1.0-cp312-cp312-manylinux_2_28_x86_64.whl";
          hash = "sha256-xS+Bqm9ldQWNjix4K/edT5/ciYh/FoJew6ZmB6XdjjA=";
        };

        pythonImportsCheck = [ "pyarrow" ];
      }
    );

  nvtxPinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "nvtx";
        version = "0.2.11";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/52/fe/9572c52876fc919de23c244451e71faffb753e5adddb70caad502956a435/nvtx-0.2.11-cp312-cp312-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          hash = "sha256-Qf3rxaVUSMGhZeOyg7TMZK03iC8Zm18iEZNwrskXvTg=";
        };

        pythonImportsCheck = [ "nvtx" ];
      }
    );

  numbaCudaPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "numba-cuda";
      version = "0.0.17";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/81/64/dff57d050f81a9538ca7df8576a2fe1b317b5436d3d8cc2e4df5e5e4ad64/numba_cuda-0.0.17-py3-none-any.whl";
        hash = "sha256-03IzXVrU5Flrs+AcBJRKvhGbDMgxyiBZ8YNFbhmn9S8=";
      };

      propagatedBuildInputs = [ ps.numba ];
      pythonImportsCheck = [ "numba_cuda" ];
    };

  pynvjitlinkCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "pynvjitlink-cu12";
        version = "0.4.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/ca/b9/13f151d534f89e225d7780682fd9a1300e0dd58e85a9c2290f623f221dda/pynvjitlink_cu12-0.4.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-j2g02E4PuhW4wO452MQ5fmMXCPl6gZbC97MILy819GU=";
        };

        pythonImportsCheck = [ "pynvjitlink" ];
      }
    );

  nvidiaNvcompCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "nvidia-nvcomp-cu12";
        version = "4.1.0.6";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/f6/3e/c90004db47c527c4f253c1c866facefbd2a5059ba50035a6967712b3b125/nvidia_nvcomp_cu12-4.1.0.6-py3-none-manylinux_2_28_x86_64.whl";
          hash = "sha256-qv+DHw/b8gYx3zLkEe3jfd9f1yl/eOdzRkQc0Ncst4c=";
        };

        pythonImportsCheck = [ "nvidia.nvcomp" ];
      }
    );

  libkvikioCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "libkvikio-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/77/01/b667118efa3b596fe7a88b9c55be0916e8f1d1c8be2ce0fe8e697580dd65/libkvikio_cu12-24.12.0-py3-none-manylinux_2_28_x86_64.whl";
          hash = "sha256-84O7+ivzh4xZDwGv1GNQZbgBOfL473dlD6YiEhhs3Uc=";
        };

        pythonImportsCheck = [ "libkvikio" ];
      }
    );

  libcudfCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "libcudf-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/88/93/dc3a27c3904aa12a32def0df330f15a85d0f01e0420b18bc0efa8b3245ba/libcudf_cu12-24.12.0-py3-none-manylinux_2_28_x86_64.whl";
          hash = "sha256-R7dTejFLRGLCSTj06RGOplv+LedEDpns8nijihSr+as=";
        };

        propagatedBuildInputs = with ps; [
          libkvikio-cu12
          nvidia-nvcomp-cu12
        ];
        preFixup = ''
          addAutoPatchelfSearchPath ${ps.libkvikio-cu12}/${final.python312.sitePackages}/libkvikio/lib64
          addAutoPatchelfSearchPath ${ps.nvidia-nvcomp-cu12}/${final.python312.sitePackages}/nvidia/nvcomp
        '';
        pythonImportsCheck = [ "libcudf" ];
      }
    );

  pylibcudfCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "pylibcudf-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/8e/2c/653ca775cefafeea2158d0c94296e6b78e050af2892f89fe21697bb737af/pylibcudf_cu12-24.12.0-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-Xiu5UfGi/d8ZdrhKpObRKAaJ2iIBTW0dX0g2TMGzLi0=";
        };

        propagatedBuildInputs = with ps; [
          cuda-python
          libcudf-cu12
          nvtx
          packaging
          pyarrow
          rmm
          typing-extensions
        ];
        preFixup = ''
          addAutoPatchelfSearchPath ${ps.libcudf-cu12}/${final.python312.sitePackages}/libcudf/lib64
          addAutoPatchelfSearchPath ${ps.libcudf-cu12}/${final.python312.sitePackages}/libcudf_cu12.libs
        '';
        pythonImportsCheck = [ "pylibcudf" ];
      }
    );

  cudfCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "cudf-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://files.pythonhosted.org/packages/70/48/1010cc8f089254bc8b4e2002511c43dcfb2d617bb1061754d4dac9627ff5/cudf_cu12-24.12.0-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-JH2Aoa3uCkrKluypowUnmTMQrA+n/FFl2ajt78mfhiQ=";
        };

        propagatedBuildInputs = with ps; [
          cachetools
          cuda-python
          cupy
          fsspec
          libcudf-cu12
          numba-cuda
          numpy
          nvtx
          packaging
          pandas
          pyarrow
          pylibcudf-cu12
          pynvjitlink-cu12
          rich
          rmm
          typing-extensions
        ];
        preFixup = ''
          addAutoPatchelfSearchPath ${ps.libcudf-cu12}/${final.python312.sitePackages}/libcudf/lib64
          addAutoPatchelfSearchPath ${ps.libcudf-cu12}/${final.python312.sitePackages}/libcudf_cu12.libs
        '';
        pythonImportsCheck = [ "cudf" ];
      }
    );

  cloudpicklePinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "cloudpickle";
      version = "3.1.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/48/41/e1d85ca3cab0b674e277c8c4f678cf66a91cd2cecf93df94353a606fe0db/cloudpickle-3.1.0-py3-none-any.whl";
        hash = "sha256-/hGs2mf2GqrsRz46/gMP6xMdeKQ0YbcYGFNjOE8boS4=";
      };

      pythonImportsCheck = [ "cloudpickle" ];
    };

  locketPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "locket";
      version = "1.0.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/db/bc/83e112abc66cd466c6b83f99118035867cecd41802f8d044638aa78a106e/locket-1.0.0-py2.py3-none-any.whl";
        hash = "sha256-tsgZpyL3tr2VW4B4F4jkpmpVYouFjTR1NrfoEyWjpeM=";
      };

      pythonImportsCheck = [ "locket" ];
    };

  toolzPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "toolz";
      version = "1.0.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/03/98/eb27cc78ad3af8e302c9d8ff4977f5026676e130d28dd7578132a457170c/toolz-1.0.0-py3-none-any.whl";
        hash = "sha256-KSyPHE51Fr+QhviFCTXHmah0A5yLz5WdR7YA5MRKYjY=";
      };

      pythonImportsCheck = [ "toolz" ];
    };

  partdPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "partd";
      version = "1.4.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/71/e7/40fb618334dcdf7c5a316c0e7343c5cd82d3d866edc100d98e29bc945ecd/partd-1.4.2-py3-none-any.whl";
        hash = "sha256-l45Kx2fsS6W4bG6qUuWio7x0iiyoOejMeY8cxs5u+w8=";
      };

      propagatedBuildInputs = with ps; [
        locket
        toolz
      ];
      pythonImportsCheck = [ "partd" ];
    };

  pynvmlPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "pynvml";
      version = "11.4.1";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/cc/0a/47be6726fd13f1f4371fa858b506228ed12bc418c07ffcaa6c0f7ceedac0/pynvml-11.4.1-py3-none-any.whl";
        hash = "sha256-0nvlQs2dBlWN4Y4t7/yAIszXNVvHOCJV1HcDjn5CTGw=";
      };

      pythonImportsCheck = [ "pynvml" ];
    };

  daskPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "dask";
      version = "2024.11.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/2a/72/33ff765a07913cb5061baa94718f3a17003aa29adc89642a68c295d47582/dask-2024.11.2-py3-none-any.whl";
        hash = "sha256-YRXEt2AV6NnZwpIragochQ4oP7f+507rvS4o6cEXww0=";
      };

      propagatedBuildInputs = with ps; [
        click
        cloudpickle
        fsspec
        packaging
        partd
        pyyaml
        toolz
      ];
      pythonImportsCheck = [ "dask" ];
    };

  distributedPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "distributed";
      version = "2024.11.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/f0/24/312287ead487290c13e62f6d987e59eb0e22b8088b3539dfe6f4062a8370/distributed-2024.11.2-py3-none-any.whl";
        hash = "sha256-pFWuAxaJruFRFys0kt5d1je2dTFyBhnBcd+YiXSYXN8=";
      };

      propagatedBuildInputs = with ps; [
        click
        cloudpickle
        dask
        jinja2
        locket
        msgpack
        packaging
        psutil
        pyyaml
        sortedcontainers
        tblib
        toolz
        tornado
        urllib3
        zict
      ];
      pythonImportsCheck = [ "distributed" ];
    };

  daskExprPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "dask-expr";
      version = "1.1.19";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/e9/57/e7996529256b13009fa8f4c34d1d7229755cc7d2b054aa43edb6ca655578/dask_expr-1.1.19-py3-none-any.whl";
        hash = "sha256-spMcICQaO8GXjMzMS4oveyexW7hc6J/sBFlbxbzyDPU=";
      };

      propagatedBuildInputs = with ps; [
        dask
        pandas
        pyarrow
      ];
      pythonImportsCheck = [ "dask_expr" ];
    };

  rapidsDaskDependencyPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "rapids-dask-dependency";
      version = "24.12.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/bc/a0/014e79fb0a1401eb62f6d2e9e512c9d3c2bf87a0163e7cd4f60338d9e1f5/rapids_dask_dependency-24.12.0-py3-none-any.whl";
        hash = "sha256-fAaihTnpyUO7DyPMCmFb63oxgB2HoIWLqihyuzbbXC4=";
      };

      propagatedBuildInputs = [
        ps.dask
        ps.distributed
        ps."dask-expr"
        ps.pynvml
      ];
    };

  daskCudfCu12PinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "dask-cudf-cu12";
      version = "24.12.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/16/07/b593d1830f580d4dfce628688a003715e033e72d91eddc39c2cb24a87127/dask_cudf_cu12-24.12.0-py3-none-any.whl";
        hash = "sha256-Oa3Cz495vWq6m5LStOd3UBdgOTKyai4Xe+GDZ8FliKA=";
      };

      propagatedBuildInputs = [
        ps.cudf
        ps.cupy
        ps.fsspec
        ps.numpy
        ps.pandas
        ps.pynvml
        ps."rapids-dask-dependency"
      ];
      pythonImportsCheck = [ "dask_cudf" ];
    };

  cumlCu12PinnedFor =
    ps:
    ps.buildPythonPackage (
      rapidsWheelDefaults
      // rec {
        pname = "cuml-cu12";
        version = "24.12.0";
        format = "wheel";

        src = final.fetchurl {
          url = "https://pypi.nvidia.com/cuml-cu12/cuml_cu12-24.12.0-cp312-cp312-manylinux_2_28_x86_64.whl";
          hash = "sha256-OPLNjWXi58er8C38ReA/ySaSbZ5ZDK+4Ffah9b7YXRg=";
        };

        propagatedBuildInputs = with ps; [
          cudf
          cupy
          cuvs
          joblib
          numba
          numpy
          packaging
          pylibraft
          rmm
          scipy
          treelite
          ps."dask-cudf-cu12"
        ];
        pythonRemoveDeps = [
          "dask-cuda"
          "nvidia-cublas-cu12"
          "nvidia-cufft-cu12"
          "nvidia-curand-cu12"
          "nvidia-cusolver-cu12"
          "nvidia-cusparse-cu12"
          "raft-dask-cu12"
        ];
        pythonImportsCheck = [ "cuml" ];
      }
    );

  scikitLearnPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "scikit-learn";
      version = "1.8.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/97/74/b7a304feb2b49df9fafa9382d4d09061a96ee9a9449a7cbea7988dda0828/scikit_learn-1.8.0-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-oLz+TQ0UrsRJIVRf0q8jOMdHHenLcB8dpMnYWQarhHo=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [
        final.stdenv.cc.cc.lib
        final.zlib
      ];
      propagatedBuildInputs = with ps; [
        joblib
        numpy
        scipy
        threadpoolctl
      ];
      pythonImportsCheck = [ "sklearn" ];
    };

  pynndescentPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "pynndescent";
      version = "0.6.0";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/py3/p/pynndescent/pynndescent-0.6.0-py3-none-any.whl";
        hash = "sha256-3Ix0hE5Mf1y9HgzWkJ2ob9x4nm/0mXM240R3nD1VOO8=";
      };

      propagatedBuildInputs = with ps; [
        joblib
        llvmlite
        numba
        numpy
        scikit-learn
        scipy
      ];
      pythonImportsCheck = [ "pynndescent" ];
    };

  umapLearnPinnedFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "umap-learn";
      version = "0.5.12";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/py3/u/umap-learn/umap_learn-0.5.12-py3-none-any.whl";
        hash = "sha256-8qhdKirctStUG+2bJ6I8oWm1a7GyMoOr7r+437ikL+U=";
      };

      propagatedBuildInputs = with ps; [
        numba
        numpy
        pynndescent
        scikit-learn
        scipy
        tqdm
      ];
      pythonImportsCheck = [ "umap" ];
    };

  # Voyager - Spotify's ANN library (not in nixpkgs)
  voyagerFor =
    ps:
    ps.buildPythonPackage rec {
      pname = "voyager";
      version = "2.1.0";
      format = "wheel";

      src = final.fetchPypi {
        inherit pname version format;
        dist = "cp312";
        python = "cp312";
        abi = "cp312";
        platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
        hash = "sha256-lBW5ySO6xJPVxo1VrlXEKJFTwj+fR4Qik03mGsuvTAE=";
      };

      # Binary wheel, no build deps needed
      propagatedBuildInputs = [ ps.numpy ];
      pythonImportsCheck = [ "voyager" ];

      meta = with final.lib; {
        description = "Spotify's library for approximate nearest-neighbor search";
        homepage = "https://github.com/spotify/voyager";
        license = licenses.asl20;
      };
    };

  # AudioMuse v3.1.1 is tested against NumPy 1.26.x. The current nixpkgs
  # scientific stack defaults to NumPy 2.x, and AudioMuse has been segfaulting
  # inside NumPy's native ufunc engine during analysis with that newer ABI.
  audiomusePythonPackages = final.python312Packages.overrideScope (
    self: super: {
      numpy = super.numpy_1;
      scipy = scipyPinnedFor self;
      llvmlite = llvmlitePinnedFor self;
      numba = numbaPinnedFor self;
      ml-dtypes = mlDtypesPinnedFor self;
      onnx = onnxPinnedFor self;
      av = avPinnedFor self;
      stopwords = stopwordsPinnedFor self;
      hf-xet = hfXetPinnedFor self;
      huggingface-hub = huggingfaceHubPinnedFor self;
      tokenizers = tokenizersPinnedFor self;
      safetensors = safetensorsPinnedFor self;
      transformers = transformersPinnedFor self;
      pandas = pandasPinnedFor self;
      pyarrow = pyarrowPinnedFor self;
      scikit-learn = scikitLearnPinnedFor self;
      pynndescent = pynndescentPinnedFor self;
      umap-learn = umapLearnPinnedFor self;
      voyager = voyagerFor self;
      cloudpickle = cloudpicklePinnedFor self;
      locket = locketPinnedFor self;
      toolz = toolzPinnedFor self;
      partd = partdPinnedFor self;
      pynvml = pynvmlPinnedFor self;
      dask = daskPinnedFor self;
      distributed = distributedPinnedFor self;
      "dask-expr" = daskExprPinnedFor self;
      "rapids-dask-dependency" = rapidsDaskDependencyPinnedFor self;
      cuda-python = cudaPythonPinnedFor self;
      cupy = cupyCuda12xPinnedFor self;
      cupy-cuda12x = self.cupy;
      nvtx = nvtxPinnedFor self;
      numba-cuda = numbaCudaPinnedFor self;
      pynvjitlink-cu12 = pynvjitlinkCu12PinnedFor self;
      nvidia-nvcomp-cu12 = nvidiaNvcompCu12PinnedFor self;
      libkvikio-cu12 = libkvikioCu12PinnedFor self;
      libcudf-cu12 = libcudfCu12PinnedFor self;
      pylibcudf-cu12 = pylibcudfCu12PinnedFor self;
      cudf = cudfCu12PinnedFor self;
      cudf-cu12 = self.cudf;
      dask-cudf-cu12 = daskCudfCu12PinnedFor self;
      rmm = rmmCu12PinnedFor self;
      rmm-cu12 = self.rmm;
      pylibraft = pylibraftCu12PinnedFor self;
      pylibraft-cu12 = self.pylibraft;
      cuvs = cuvsCu12PinnedFor self;
      cuvs-cu12 = self.cuvs;
      treelite = treelitePinnedFor self;
      cuml = cumlCu12PinnedFor self;
      cuml-cu12 = self.cuml;
      onnxruntimeGpu = onnxruntimeGpuFor self;
    }
  );

  voyager = voyagerFor audiomusePythonPackages;

  # pyloudnorm - ITU-R BS.1770 loudness normalization
  # pyloudnorm = final.python312Packages.buildPythonPackage rec {
  #   pname = "pyloudnorm";
  #   version = "0.1.1";
  #   src = final.python312Packages.fetchPypi {
  #     inherit pname version;
  #     hash = "sha256-Y81OGX3qTneVFg6gjtAtMYCRvOiD5Dam28WWMya3Hh4=";
  #   };
  #   propagatedBuildInputs = with final.python312Packages; [ numpy scipy ];
  #   pythonImportsCheck = [ "pyloudnorm" ];
  #   meta = with final.lib; {
  #     description = "ITU-R BS.1770-4 loudness normalization in Python";
  #     homepage = "https://github.com/csteinmetz1/pyloudnorm";
  #     license = licenses.mit;
  #   };
  # };

  # AudioMuse-AI Python environment with all dependencies
  audiomuse-ai-python = final.python312.withPackages (
    _: with audiomusePythonPackages; [
      # Web framework
      flask
      flask-cors
      flasgger
      sqlglot

      # Task queue
      redis
      rq

      # Database
      psycopg2

      # Audio processing
      librosa
      soundfile
      resampy
      pydub
      mutagen
      mpd2
      av

      # ML/Scientific
      numpy
      scipy
      numba
      scikit-learn
      umap-learn
      transformers
      sentencepiece

      # ONNX
      onnx
      onnxruntimeGpu

      # AudioMuse's upstream GPU clustering stack
      cupy
      rmm
      pylibraft
      cuvs
      cuml

      # Utilities
      pyyaml
      requests
      six
      flatbuffers
      numkong
      stopwords
      rapidfuzz
      ftfy
      packaging
      protobuf
      httpx
      psutil
      langdetect
      pyjwt
      argon2-cffi
      gunicorn
      zstandard
      wn

      # LLM integrations
      google-genai
      mistralai

      # MCP (Model Context Protocol)
      mcp

      # Loudness normalization
      # pyloudnorm

      # Voyager (from our custom package)
      voyager
    ]
  );

  audiomuse-ai-music-server-src = final.fetchFromGitHub {
    owner = "NeptuneHub";
    repo = "AudioMuse-AI-MusicServer";
    rev = "a761a7c6602e4dad10399f3d1c5129317af61c63";
    hash = "sha256-4ksXTBYfg+A3fMHLv9nmZ4fPKdMUF2RCamqev/VrCb4=";
  };

  audiomuse-ai-music-server-frontend = final.buildNpmPackage {
    pname = "audiomuse-ai-music-server-frontend";
    version = "85";

    src = "${audiomuse-ai-music-server-src}/music-server-frontend";

    npmDepsHash = "sha256-NtAMH61xOVeFJ+jEAKclzNrbbw2QNoyAU4gQQaRSXig=";
    nodejs = final.nodejs;

    postPatch = ''
      cp ${./audiomuse-music-server-frontend-package-lock.json} package-lock.json
      substituteInPlace src/components/MusicViews.jsx \
        --replace-fail "searchTerm.length >= 3" "searchTerm.length >= 2" \
        --replace-fail "searchTerm.length > 0 && searchTerm.length < 3" "searchTerm.length > 0 && searchTerm.length < 2"
    '';

    env.CI = "false";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/audiomuse-ai-music-server/frontend
      cp -r build/* $out/share/audiomuse-ai-music-server/frontend/
      runHook postInstall
    '';
  };
in
tmuxOverlay
// {
  inherit audiomuse-ai-music-server-frontend;

  # AudioMuse-AI - Music analysis and playlist generation service
  audiomuse-ai = final.stdenvNoCC.mkDerivation {
    pname = "audiomuse-ai";
    version = "3.1.1";

    src = final.fetchFromGitHub {
      owner = "NeptuneHub";
      repo = "AudioMuse-AI";
      rev = "v3.1.1";
      hash = "sha256-6mDcHFFkPs4HAuMD/trQDc/+NCNs7Q1B1SmqabrQcfw=";
    };

    nativeBuildInputs = [ final.makeWrapper ];

    buildInputs = [
      audiomuse-ai-python
      final.ffmpeg
    ];

    postPatch = ''
      # v3.1.1 already reads TEMP_DIR from the environment.
      runtime_key_block=$(cat <<'EOF'
          'LYRICS_INSTRUMENTAL_AXIS_FILL',
          # Runtime/package settings are owned by Nix. The setup DB can contain
          # stale values from previous container-style runs; do not let those
          # override the service environment.
          'PER_SONG_MODEL_RELOAD',
          'USE_GPU_CLUSTERING',
          'EMBEDDING_MODEL_PATH',
          'PREDICTION_MODEL_PATH',
          'CLAP_AUDIO_MODEL_PATH',
          'CLAP_TEXT_MODEL_PATH',
          'CLAP_AUDIO_N_MELS',
          'CLAP_AUDIO_N_FFT',
          'CLAP_AUDIO_HOP_LENGTH',
          'CLAP_AUDIO_FMIN',
          'CLAP_AUDIO_MEL_TRANSPOSE',
          'LYRICS_MODEL_DIR',
          'LYRICS_WHISPER_MODEL_DIR',
          'SILERO_VAD_ONNX_PATH',
          'LYRICS_GTE_ONNX_PATH',
          'LYRICS_GTE_TOKENIZER_DIR',
          'MODELS_PATH',
          'MUSIC_FOLDER',
          'TEMP_DIR',
          'VOYAGER_EF_CONSTRUCTION',
          'VOYAGER_M',
      EOF
      )
      substituteInPlace config.py \
        --replace-fail "    'LYRICS_INSTRUMENTAL_AXIS_FILL'," "$runtime_key_block"

      substituteInPlace app.py \
        --replace-fail "app.run(debug=False, host='0.0.0.0', port=8000)" \
                       "app.run(debug=False, host=os.environ.get('FLASK_HOST', '0.0.0.0'), port=int(os.environ.get('FLASK_PORT', '8000')))"

      layout_base_path_block=$(cat <<'EOF'
          <script>
              window.AUDIOMUSE_BASE_PATH = {{ request.script_root|tojson }};
              window.audiomuseUrl = function(path) {
                  var base = window.AUDIOMUSE_BASE_PATH || "";
                  if (!path || path.charAt(0) !== "/" || !base || path.indexOf(base + "/") === 0) {
                      return path;
                  }
                  return base + path;
              };
              (function() {
                  var originalFetch = window.fetch;
                  window.fetch = function(resource, init) {
                      if (typeof resource === "string" && resource.charAt(0) === "/") {
                          resource = window.audiomuseUrl(resource);
                      }
                      return originalFetch.call(this, resource, init);
                  };
              })();
          </script>

          {% block bodyAdditions %}
      EOF
      )
      substituteInPlace templates/includes/layout.html \
        --replace-fail '    {% block bodyAdditions %}' "$layout_base_path_block"

      # v3.1.1 already uses url_for('auth_endpoint') in the login form.

      substituteInPlace static/setup.js \
        --replace-fail "window.location.href = '/';" \
                       "window.location.href = window.audiomuseUrl ? window.audiomuseUrl('/') : '/';"

      # Fix CLAP Conv fallback: use EXHAUSTIVE algo search + relaxed memory arena
      substituteInPlace tasks/clap_analyzer.py \
        --replace-fail "'cudnn_conv_algo_search': 'DEFAULT'" \
                       "'cudnn_conv_algo_search': 'EXHAUSTIVE'" \
        --replace-fail "'arena_extend_strategy': 'kSameAsRequested'" \
                       "'arena_extend_strategy': 'kNextPowerOfTwo'"

      # librosa 0.11 returns tempo as a one-element ndarray; AudioMuse
      # assumes it is scalar and crashes while saving basic track features.
      tempo_block=$(cat <<'EOF'
          tempo, _ = librosa.beat.beat_track(y=audio, sr=sr)
          tempo_arr = np.asarray(tempo)
          tempo = float(tempo_arr.reshape(-1)[0]) if tempo_arr.size else 0.0
      EOF
      )
      substituteInPlace tasks/analysis/song.py \
        --replace-fail "    tempo, _ = librosa.beat.beat_track(y=audio, sr=sr)" "$tempo_block" \
        --replace-fail "        return float(tempo), energy, _KEYS[mi], 'major'" \
                       "        return tempo, energy, _KEYS[mi], 'major'" \
        --replace-fail "    return float(tempo), energy, _KEYS[ni], 'minor'" \
                       "    return tempo, energy, _KEYS[ni], 'minor'"

      # v3.1.1 guards optional Mistral imports in tasks/ai/providers/mistral.py.
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/audiomuse-ai
      cp -r . $out/lib/audiomuse-ai/

      mkdir -p $out/bin
      cat > $out/lib/audiomuse-ai/nix_launcher.py <<'PY'
      import os

      from app import app

      app.run(
          debug=False,
          host=os.environ.get("FLASK_HOST", "0.0.0.0"),
          port=int(os.environ.get("FLASK_PORT", "8000")),
      )
      PY

      # Main Flask app
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai \
        --add-flags "$out/lib/audiomuse-ai/nix_launcher.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      # RQ Worker
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai-worker \
        --add-flags "$out/lib/audiomuse-ai/rq_worker.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      # High-priority RQ Worker
      makeWrapper ${audiomuse-ai-python}/bin/python $out/bin/audiomuse-ai-worker-high \
        --add-flags "$out/lib/audiomuse-ai/rq_worker_high_priority.py" \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set PYTHONPATH "$out/lib/audiomuse-ai"

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "AI-powered music analysis and playlist generation";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  # AudioMuse-AI MusicServer - Open Subsonic-compatible music server
  audiomuse-ai-music-server = final.buildGoModule {
    pname = "audiomuse-ai-music-server";
    version = "85";

    src = audiomuse-ai-music-server-src;
    sourceRoot = "${audiomuse-ai-music-server-src.name}/music-server-backend";

    patches = [
      ../patches/audiomuse-music-server-scrobble-history.patch
      ../patches/audiomuse-music-server-listenbrainz-forward.patch
      ../patches/audiomuse-music-server-fast-search.patch
      ../patches/audiomuse-music-server-wrhythm-albums.patch
      ../patches/audiomuse-music-server-transcode-ranges.patch
      ../patches/audiomuse-music-server-coverart-fallback.patch
    ];
    patchFlags = [
      "-p2"
      "-l"
    ];

    vendorHash = "sha256-T+hmB4mFWQoETpc/A4GJi+RapkiiGiTiNigFTkjAZbc=";

    nativeBuildInputs = [
      final.makeWrapper
      final.pkg-config
      final.perl
    ];

    buildInputs = [ final.sqlite ];

    env.CGO_ENABLED = "1";

    postUnpack = ''
      pushd "$sourceRoot"
      sed -i 's/\r$//' main.go
      sed -i 's/\r$//' models.go
      sed -i 's/\r$//' subsonic_search_handlers.go
      sed -i 's/\r$//' subsonic_helpers.go
      sed -i 's/\r$//' subsonic_music_handlers.go
      sed -i 's/\r$//' subsonic_playlist_handlers.go
      popd
    '';

    prePatch = ''
      sed -i 's/\r$//' main.go
      sed -i 's/\r$//' models.go
      sed -i 's/\r$//' subsonic_search_handlers.go
      sed -i 's/\r$//' subsonic_helpers.go
      sed -i 's/\r$//' subsonic_music_handlers.go
      sed -i 's/\r$//' subsonic_playlist_handlers.go
    '';

    postPatch = ''
      substituteInPlace main.go \
        --replace-fail 'Addr:              ":8080",' \
                       'Addr:              ":" + getEnv("PORT", "8080"),' \
        --replace-fail 'log.Println("[GIN-debug] Listening and serving HTTP on :8080")' \
                       'log.Printf("[GIN-debug] Listening and serving HTTP on :%s", getEnv("PORT", "8080"))'

      # Internal 85 handles nowPlaying and randomSongs natively. Retain the
      # response mappings that are still absent upstream.
      perl -0pi -e 's/(case \*SubsonicAlbumWithSongs:\n\t\t\tbodyMap\["album"\] = body\n)/$1\t\tcase *SubsonicArtistWithAlbums:\n\t\t\tbodyMap["artist"] = body\n/' subsonic_helpers.go
      perl -0pi -e 's/(case \*SubsonicSimilarArtists:\n\t\t\tbodyMap\["similarArtists2"\] = body\n)/$1\t\tcase *SubsonicTopSongs:\n\t\t\tbodyMap["topSongs"] = body\n\t\tcase *SubsonicSimilarSongs:\n\t\t\tbodyMap["similarSongs2"] = body\n/' subsonic_helpers.go
    '';

    buildPhase = ''
      runHook preBuild
      go build -tags fts5 -o music-server .
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 music-server $out/bin/audiomuse-ai-music-server
      cp -r ${audiomuse-ai-music-server-frontend}/share $out/

      wrapProgram $out/bin/audiomuse-ai-music-server \
        --prefix PATH : ${final.lib.makeBinPath [ final.ffmpeg ]} \
        --set-default FRONTEND_BUILD_DIR "$out/share/audiomuse-ai-music-server/frontend" \
        --set-default GIN_MODE release \
        --run 'export DATABASE_PATH="''${DATABASE_PATH:-''${XDG_STATE_HOME:-$HOME/.local/share}/audiomuse-ai-music-server/music.db}"'

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Open Subsonic-compatible AudioMuse-AI music server";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI-MusicServer";
      license = licenses.mit;
      mainProgram = "audiomuse-ai-music-server";
      platforms = platforms.linux;
    };
  };

  audiomuse-ai-music-server-import-koito-history =
    final.writers.writePython3Bin "audiomuse-ai-music-server-import-koito-history"
      {
        flakeIgnore = [
          "E501"
          "W503"
        ];
      }
      ''
        import argparse
        import datetime as dt
        import hashlib
        import json
        import os
        import sys
        import time
        import urllib.error
        import urllib.parse
        import urllib.request


        def env(name, default=None):
            value = os.environ.get(name)
            return value if value not in (None, "") else default


        def request_json(method, url, *, headers=None, params=None):
            if params:
                separator = "&" if "?" in url else "?"
                url = url + separator + urllib.parse.urlencode(params)
            req = urllib.request.Request(url, method=method, headers=headers or {})
            with urllib.request.urlopen(req, timeout=30) as response:
                return json.load(response)


        def subsonic_params(user, password):
            return {
                "u": user,
                "p": "enc:" + password.encode("utf-8").hex(),
                "v": "1.16.1",
                "c": "audiomuse-koito-history-import",
                "f": "json",
            }


        def normalize(value):
            return " ".join((value or "").casefold().split())


        def parse_time(value):
            normalized = value.replace("Z", "+00:00")
            parsed = dt.datetime.fromisoformat(normalized)
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed


        def load_seen(path):
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    return set(line.strip() for line in handle if line.strip())
            except FileNotFoundError:
                return set()


        def append_seen(path, key):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "a", encoding="utf-8") as handle:
                handle.write(key + "\n")


        def koito_listens(base_url, token, page, limit):
            return request_json(
                "GET",
                urllib.parse.urljoin(base_url.rstrip("/") + "/", "apis/web/v1/listens"),
                headers={"Authorization": "Token " + token},
                params={"period": "all_time", "page": page, "limit": limit},
            )


        def search_song(audiomuse_url, auth, listen):
            track = listen.get("track", {})
            title = track.get("title", "")
            artists = track.get("artists") or []
            artist = artists[0].get("name", "") if artists else ""
            duration = int(track.get("duration") or 0)

            params = dict(auth)
            params.update({"query": title, "songCount": 20})
            data = request_json(
                "GET",
                urllib.parse.urljoin(audiomuse_url.rstrip("/") + "/", "rest/search3.view"),
                params=params,
            )
            songs = (
                data.get("subsonic-response", {})
                .get("searchResult3", {})
                .get("song", [])
            )
            if isinstance(songs, dict):
                songs = [songs]

            title_norm = normalize(title)
            artist_norm = normalize(artist)
            best = None
            best_score = -1
            for song in songs:
                score = 0
                if normalize(song.get("title")) == title_norm:
                    score += 5
                if artist_norm and (
                    artist_norm in normalize(song.get("artist"))
                    or normalize(song.get("artist")) in artist_norm
                ):
                    score += 4
                song_duration = int(song.get("duration") or 0)
                if duration and song_duration and abs(song_duration - duration) <= 8:
                    score += 2
                if score > best_score:
                    best = song
                    best_score = score

            return best if best_score >= 5 else None


        def scrobble(audiomuse_url, auth, song_id, played_at):
            params = dict(auth)
            params.update({"id": song_id, "time": str(int(played_at.timestamp() * 1000))})
            return request_json(
                "GET",
                urllib.parse.urljoin(audiomuse_url.rstrip("/") + "/", "rest/scrobble.view"),
                params=params,
            )


        def main():
            parser = argparse.ArgumentParser(description="Import Koito listen history into AudioMuse-AI MusicServer.")
            parser.add_argument("--koito-url", default=env("KOITO_URL", "http://127.0.0.1:4110"))
            parser.add_argument("--koito-token", default=env("KOITO_TOKEN"))
            parser.add_argument("--audiomuse-url", default=env("AUDIOMUSE_MUSIC_SERVER_URL", "http://127.0.0.1:9081"))
            parser.add_argument("--audiomuse-user", default=env("AUDIOMUSE_MUSIC_SERVER_USER", "admin"))
            parser.add_argument("--audiomuse-password", default=env("AUDIOMUSE_MUSIC_SERVER_PASSWORD", "admin"))
            parser.add_argument("--page-size", type=int, default=int(env("KOITO_IMPORT_PAGE_SIZE", "100")))
            parser.add_argument("--max-pages", type=int, default=int(env("KOITO_IMPORT_MAX_PAGES", "0")))
            parser.add_argument("--state-file", default=env("KOITO_IMPORT_STATE_FILE", os.path.expanduser("~/.cache/audiomuse-ai-music-server/koito-import.seen")))
            parser.add_argument("--dry-run", action="store_true")
            args = parser.parse_args()

            if not args.koito_token:
                print("KOITO_TOKEN or --koito-token is required", file=sys.stderr)
                return 2

            auth = subsonic_params(args.audiomuse_user, args.audiomuse_password)
            seen = load_seen(args.state_file)
            imported = skipped = missing = 0
            page = 0

            while True:
                if args.max_pages and page >= args.max_pages:
                    break
                payload = koito_listens(args.koito_url, args.koito_token, page, args.page_size)
                items = payload.get("items", [])
                if not items:
                    break
                for listen in items:
                    track = listen.get("track", {})
                    artists = track.get("artists") or []
                    first_artist = artists[0].get("name", "") if artists else ""
                    key_raw = "|".join([listen.get("time", ""), track.get("title", ""), first_artist])
                    key = hashlib.sha256(key_raw.encode("utf-8")).hexdigest()
                    if key in seen:
                        skipped += 1
                        continue
                    song = search_song(args.audiomuse_url, auth, listen)
                    if song is None:
                        missing += 1
                        print("missing: {} - {}".format(first_artist, track.get("title", "")), file=sys.stderr)
                        continue
                    played_at = parse_time(listen["time"])
                    if args.dry_run:
                        print("would import: {} - {} -> {} @ {}".format(first_artist, track.get("title", ""), song["id"], listen["time"]))
                    else:
                        scrobble(args.audiomuse_url, auth, song["id"], played_at)
                        append_seen(args.state_file, key)
                        seen.add(key)
                    imported += 1
                    time.sleep(0.05)
                if not payload.get("has_next_page", False):
                    break
                page += 1

            print(f"imported={imported} skipped={skipped} missing={missing}")
            return 0


        if __name__ == "__main__":
            raise SystemExit(main())
      '';

  pam-insults = final.stdenv.mkDerivation {
    pname = "pam-insults";
    version = "unstable-2025-12-30";

    src = final.fetchFromGitHub {
      owner = "cgoesche";
      repo = "pam-insults";
      rev = "6ee9d94a301413aaa882fd3ee9126151a0ce2bfc";
      hash = "sha256-EVT2BtPL2355E1Sxks8zEZfazkyXtIezoaGy8BAyYvA=";
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

  # AudioMuse-AI ONNX models. App v3.1.1 uses the lean v5 model pack and
  # the distilled DCLAP student audio model by default.
  audiomuse-ai-models = final.stdenvNoCC.mkDerivation {
    pname = "audiomuse-ai-models";
    version = "5.0.0";

    dontUnpack = true;

    # MusicNN models
    musicnn_embedding = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/musicnn_embedding.onnx";
      hash = "sha256-pIrYh5UKVXrvu03N31itSAIhP/X8b7Ue2jUHzXl7ubA=";
    };
    musicnn_prediction = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/musicnn_prediction.onnx";
      hash = "sha256-DU543UPGEK7IjAmeQfSolpeX2lrCYS6myiH6qeGkKPM=";
    };

    # DCLAP student audio model used by the v3.1.1 defaults.
    clap_audio_student = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI-DCLAP/releases/download/v1/model_epoch_36.onnx";
      hash = "sha256-F4YEA/j8kK/4rAYyoHQeteWNjAsK0vzlztlnJ0sOqXE=";
    };
    clap_audio_student_data = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI-DCLAP/releases/download/v1/model_epoch_36.onnx.data";
      hash = "sha256-KnNbI8Kq17Etn/yFM0zrzGWcB2ltL/YOLjeNoott9lc=";
    };
    clap_text = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/clap_text_model.onnx";
      hash = "sha256-IA1I85Bf8fJyr1AG3ZhR+UBxp93k6v2cB7wJxaxlpxQ=";
    };

    # HuggingFace models (BERT, RoBERTa, etc.)
    huggingface_models = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/huggingface_models.tar.gz";
      hash = "sha256-AqeNbkI0BMcnEWj3QPF+Q9vBCUf3Rt/EIFZwinRsyz0=";
    };
    lyrics_model_whisper = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/lyrics_model_whisper.tar.gz";
      hash = "sha256-+p9IJeGpGDlMGmOwy3ykOrHfi+kDVa0D56+V7j0/FRE=";
    };
    lyrics_model_silero_vad = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/lyrics_model_silero_vad.tar.gz";
      hash = "sha256-ZeXlw9e/XlvHxHv0K7vmadv6FZVDvUdeDCPO06p6w7Q=";
    };
    lyrics_model_gte_vnni = final.fetchurl {
      url = "https://github.com/NeptuneHub/AudioMuse-AI/releases/download/v5.0.0-model/lyrics_model_gte_vnni.tar.gz";
      hash = "sha256-X4pJyHPHYvAajaeQ9B+Z29qsbx8g1MCi26QHzMYMx8w=";
    };

    nativeBuildInputs = [
      final.gnutar
      final.gzip
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/models

      # MusicNN models
      cp $musicnn_embedding $out/models/musicnn_embedding.onnx
      cp $musicnn_prediction $out/models/musicnn_prediction.onnx

      # CLAP models
      cp $clap_audio_student $out/models/model_epoch_36.onnx
      cp $clap_audio_student_data $out/models/model_epoch_36.onnx.data
      cp $clap_text $out/models/clap_text_model.onnx

      # HuggingFace models (extract tarball)
      mkdir -p $out/cache/huggingface
      tar -xzf $huggingface_models -C $out/cache/huggingface

      # Lyrics models
      tar -xzf $lyrics_model_whisper -C $out/models
      tar -xzf $lyrics_model_silero_vad -C $out/models
      tar -xzf $lyrics_model_gte_vnni -C $out/models

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "ONNX models for AudioMuse-AI";
      homepage = "https://github.com/NeptuneHub/AudioMuse-AI";
      license = licenses.mit;
      platforms = platforms.all;
    };
  };

  # Navidrome plugins
  navidromePlugins = {
    # AudioMuse-AI plugin for Navidrome
    audiomuse-ai = final.buildGoModule {
      pname = "audiomuse-ai-nv-plugin";
      version = "9";

      src = final.fetchFromGitHub {
        owner = "NeptuneHub";
        repo = "AudioMuse-AI-NV-plugin";
        rev = "v9";
        hash = "sha256-46QZfUJa1xrwUgA2UfN8pex8hKMj3TOQvfYOtKQM8ug=";
      };

      nativeBuildInputs = [ final.zip ];

      vendorHash = "sha256-mXes+doBSa5kcfHp1cuzTz30wnyyPN7NLC0iOSL8FDo=";

      env.CGO_ENABLED = "0";

      buildPhase = ''
        runHook preBuild
        GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/navidrome-plugins
        zip -j $out/share/navidrome-plugins/audiomuse-ai.ndp plugin.wasm manifest.json
        runHook postInstall
      '';

      meta = with final.lib; {
        description = "AudioMuse-AI plugin for Navidrome - AI-powered similar tracks";
        homepage = "https://github.com/NeptuneHub/AudioMuse-AI-NV-plugin";
        license = licenses.mit;
      };
    };

    discord-rich-presence = final.buildGoModule {
      pname = "discord-rich-presence";
      version = "2.0.0";

      src = final.fetchFromGitHub {
        owner = "navidrome";
        repo = "discord-rich-presence-plugin";
        rev = "v2.0.0";
        hash = "sha256-j4iGymXH9JstPGdpPl5TFLiH8ShfE46U+BZk1n7a2yQ=";
      };

      nativeBuildInputs = [ final.zip ];

      vendorHash = "sha256-5ZlqyUa+UcLCBdLQaYAlb818Y8sOENjIFfb2hpRsbpQ=";

      env.CGO_ENABLED = "0";

      buildPhase = ''
        runHook preBuild
        GOOS=wasip1 GOARCH=wasm go build -buildmode=c-shared -o plugin.wasm .
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/navidrome-plugins
        # Create .ndp package (zip file with manifest.json and plugin.wasm)
        zip -j $out/share/navidrome-plugins/discord-rich-presence.ndp plugin.wasm manifest.json
        runHook postInstall
      '';

      meta = with final.lib; {
        description = "Discord Rich Presence plugin for Navidrome";
        homepage = "https://github.com/navidrome/discord-rich-presence-plugin";
        license = licenses.gpl3Only;
      };
    };
  };

  # Navidrome 0.63.2 with plugin support
  # Use: pkgs.navidrome.override { plugins = with pkgs.navidromePlugins; [ discord-rich-presence ]; }
  navidrome = final.lib.makeOverridable (
    {
      plugins ? [ ],
    }:
    prev.navidrome.overrideAttrs (oldAttrs: rec {
      version = "0.63.2";
      src = final.fetchFromGitHub {
        owner = "navidrome";
        repo = "navidrome";
        rev = "v${version}";
        hash = "sha256-s0Pd6yT9NX2VFSPbLPX6Zqon8Y3qyDPGCKvqHPxcZ88=";
      };
      vendorHash = "sha256-lNjOVrlRD6ptDBpmfGYCN3Vkal9ACciOyS1RANzKYK4=";
      npmDeps = final.fetchNpmDeps {
        inherit src;
        sourceRoot = "${src.name}/ui";
        hash = "sha256-uRF9cf6HZE0gyCvGTEZ520d2gMsxmccEYLJBgc47pMg=";
      };

      patches = (oldAttrs.patches or [ ]) ++ [
        ../patches/navidrome-default-enable-managed-plugins.patch
      ];

      postInstall = ''
        mkdir -p $out/share/plugins/
        ${final.lib.concatMapStringsSep "\n" (plugin: ''
          cp ${plugin}/share/navidrome-plugins/*.ndp $out/share/plugins/
        '') plugins}
      '';

      passthru = oldAttrs.passthru // {
        inherit plugins;
      };
    })
  ) { };

  # Agent Deck - TUI for managing AI coding agent sessions (Claude Code, Codex, etc.)
  agent-deck = final.buildGoModule {
    pname = "agent-deck";
    version = "1.11.0";

    src = final.fetchFromGitHub {
      owner = "asheshgoplani";
      repo = "agent-deck";
      rev = "v1.11.0";
      hash = "sha256-PHNdIqGBvgg06zFlqOY6dN2aSu+HivNaxp7DHCyMqTI=";
    };

    patches = [
      ../patches/agent-deck-preserve-collapsed-groups.patch
      ../patches/agent-deck-remove-csiureader.patch
      ../patches/agent-deck-add-psi.patch
      ../patches/agent-deck-disable-preview-fetch.patch
      ../patches/agent-deck-disable-preview-generation.patch
      ../patches/agent-deck-disable-menu-polling.patch
    ];

    postPatch = ''
      substituteInPlace internal/session/conductor.go \
        --replace-fail "/bin/bash" "${final.bash}/bin/bash"
    '';

    vendorHash = "sha256-rLhOjYfLAPPRTfLFPMlxrjSSqmHFmPoXPFZbaevEgtw=";

    subPackages = [ "cmd/agent-deck" ];

    nativeBuildInputs = [ final.makeWrapper ];
    nativeCheckInputs = [ final.git ];

    postInstall = ''
      wrapProgram $out/bin/agent-deck \
        --prefix PATH : ${
          final.lib.makeBinPath [
            final.tmux
            final.git
            final.bash
          ]
        }
    '';

    meta = with final.lib; {
      description = "Terminal session manager for AI coding agents";
      homepage = "https://github.com/asheshgoplani/agent-deck";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  forgejo-mcp = final.buildGoModule rec {
    pname = "forgejo-mcp";
    version = "2.30.2";

    src = final.fetchFromGitHub {
      owner = "goern";
      repo = "forgejo-mcp";
      rev = "v${version}";
      hash = "sha256-czL2jfFalnbDzvtEAOLS82c+zuGpWgUrMFlu/vj1C8Q=";
    };

    patches = [ ../patches/forgejo-mcp-action-job-logs.patch ];

    vendorHash = "sha256-QDJRbF4mZzBv1vxvo1ZQJaUJayRHj1jMgjaRfAmLMik=";

    meta = with final.lib; {
      description = "MCP server for interacting with Forgejo repositories";
      homepage = "https://github.com/goern/forgejo-mcp";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "forgejo-mcp";
    };
  };

  forgejo = final.forgejo-lts;

  forgejo-lts =
    (final.callPackage (import "${prev.path}/pkgs/by-name/fo/forgejo/generic.nix" {
      version = "15.0.6";
      hash = "sha256-kWmBs/qAiBlmVcSwBM+rXapDbC8IpJtKfQRVPLH4geI=";
      npmDepsHash = "sha256-wPta+potJJeOac7TyMk3BZg6su6mgHCEgesrsr7SCR4=";
      vendorHash = "sha256-Kx+mP3GKfEOlsy5bkF7QYDebkrV+FHr37aQC4th/XJM=";
      lts = true;
    }) { }).overrideAttrs
      (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [ ../patches/forgejo-actions-api-jobs-logs.patch ];
      });

  # NixOS has no ld.so cache for DCGM, so the local patch bypasses upstream's
  # /sbin/ldconfig prerequisite check. Runtime loading is still enforced by the
  # binary's RPATH; replace this bypass with a Nix-aware upstream check later.
  prometheus-dcgm-exporter = prev.prometheus-dcgm-exporter.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ../patches/dcgm-exporter-fix-ldconfig.patch ];
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/etc
      cp $src/etc/*.csv $out/etc/
    '';
  });

  # osm2pgsql uses opencv which is built with CUDA - need CUDA toolkit for CMake to find nvcc
  osm2pgsql = prev.osm2pgsql.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
      final.cudaPackages.cuda_nvcc
    ];
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
      final.cudaPackages.cuda_cudart
    ];
  });

  # Koito - ListenBrainz-compatible scrobbler
  # PostgreSQL-to-SQLite migration bridge. Run this with KOITO_DATABASE_URL and
  # KOITO_SQLITE_ENABLED=true; it creates KOITO_CONFIG_DIR/koito.db.
  koito_0_2_1 =
    let
      version = "0.2.1";
      src = final.fetchFromGitHub {
        owner = "gabehf";
        repo = "Koito";
        rev = "ec1c8172b866f48d698d85fe65e3229da02ca2ba";
        hash = "sha256-qDQYVg/adZwGT5O+vSFd2HeSukpDXcalFXtILaP7QbI=";
      };

      frontend = final.stdenv.mkDerivation {
        pname = "koito-frontend";
        inherit version;
        src = "${src}/client";

        yarnOfflineCache = final.fetchYarnDeps {
          yarnLock = "${src}/client/yarn.lock";
          hash = "sha256-vnddE1H3FROkvh7tL0MzkSbsS9Na2s6oy5rIBhJtM9M=";
        };

        nativeBuildInputs = [
          final.yarnConfigHook
          final.yarnBuildHook
          final.nodejs
        ];

        env.VITE_KOITO_VERSION = version;
        env.VITE_BASE_PATH = "/koito/";

        postPatch = ''
                    substituteInPlace vite.config.ts \
                      --replace-fail "const isDocker = process.env.BUILD_TARGET === 'docker';" "const isDocker = process.env.BUILD_TARGET === 'docker';
          const basePath = process.env.VITE_BASE_PATH || '/';" \
                      --replace-fail 'export default defineConfig({' 'export default defineConfig({
            base: basePath,'

                    substituteInPlace react-router.config.ts \
                      --replace-fail 'import type { Config } from "@react-router/dev/config";' 'import type { Config } from "@react-router/dev/config";
          const basePath = (process.env.VITE_BASE_PATH || "/").replace(/\/$/, "") || undefined;' \
                      --replace-fail 'ssr: false,' 'ssr: false,
            basename: basePath === "/" ? undefined : basePath,'
        '';

        dontYarnInstall = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r build/client/* $out/
          runHook postInstall
        '';
      };
    in
    final.buildGoModule {
      pname = "koito";
      inherit version src;

      vendorHash = "sha256-KuGNUqKWYyLykfsRdwao6jI5nvD+u95XFxo2EfOJeJg=";

      env.CGO_ENABLED = "1";

      nativeBuildInputs = [ final.pkg-config ];
      buildInputs = [ final.vips ];

      postPatch = ''
        substituteInPlace engine/engine.go \
          --replace-fail 'l.Info().Msg("Engine: Migration complete; proceeding with SQLite")' 'l.Info().Msg("Engine: Migration complete; proceeding with SQLite")
        if strings.ToLower(getenv("KOITO_MIGRATE_ONLY")) == "true" {
            l.Info().Msg("Engine: KOITO_MIGRATE_ONLY set; exiting after migration")
            return nil
        }'
      '';

      ldflags = [
        "-s"
        "-w"
        "-X main.Version=${version}"
      ];

      subPackages = [ "cmd/api" ];

      postInstall = ''
        mkdir -p $out/share/koito/client/build/client
        mkdir -p $out/share/koito/client/public

        cp -r ${frontend}/* $out/share/koito/client/build/client/
        cp -r $src/client/public/* $out/share/koito/client/public/
        cp -r $src/db $out/share/koito/
        cp -r $src/assets $out/share/koito/

        mv $out/bin/api $out/bin/koito
      '';

      meta = with final.lib; {
        description = "ListenBrainz-compatible scrobbler";
        homepage = "https://github.com/gabehf/koito";
        license = licenses.agpl3Plus;
        platforms = platforms.linux;
      };
    };

  # Upstream v0.3.x is SQLite-only. If upgrading from PostgreSQL, run v0.2.1
  # first with KOITO_DATABASE_URL and KOITO_SQLITE_ENABLED=true so it creates
  # KOITO_CONFIG_DIR/koito.db, then switch to this package.
  koito =
    let
      version = "0.3.2";
      upstreamSrc = final.fetchFromGitHub {
        owner = "gabehf";
        repo = "Koito";
        rev = "daae636f8e3b1dd4c67bfa0c07c93ab50ad8e15a";
        hash = "sha256-68+Z4Alzu+4v/PxU1IOboqZkF1pO+y6gswuO+HPS7dk=";
      };
      src = final.applyPatches {
        name = "koito-${version}-subpath-source";
        src = upstreamSrc;
        patches = [ ../patches/koito-subpath-support.patch ];
      };
      missingHashes = ./koito-0.3.1-missing-hashes.json;

      # Frontend build using Yarn Berry hooks.
      frontend = final.stdenv.mkDerivation {
        pname = "koito-frontend";
        inherit version;
        src = "${src}/client";
        inherit missingHashes;

        yarnOfflineCache = final.yarn-berry_4.fetchYarnBerryDeps {
          yarnLock = "${upstreamSrc}/client/yarn.lock";
          inherit missingHashes;
          hash = "sha256-VIlWld21GScJ/2UUkKQISM9jyU9wCVwwDNKkge+K044=";
        };

        nativeBuildInputs = [
          final.yarn-berry_4
          final.yarn-berry_4.yarnBerryConfigHook
          final.nodejs
        ];

        env.VITE_KOITO_VERSION = version;
        # Subpath deployment - set base path via env var (cleaner than patching)
        env.VITE_BASE_PATH = "/koito/";

        postPatch = ''
                    sed -i '/^approvedGitRepositories:/,+2d' .yarnrc.yml

                    substituteInPlace vite.config.ts \
                      --replace-fail 'const isDocker = process.env.BUILD_TARGET === "docker";' 'const isDocker = process.env.BUILD_TARGET === "docker";
          const basePath = process.env.VITE_BASE_PATH || "/";' \
                      --replace-fail 'export default defineConfig({' 'export default defineConfig({
            base: basePath,'

                    substituteInPlace react-router.config.ts \
                      --replace-fail 'import type { Config } from "@react-router/dev/config";' 'import type { Config } from "@react-router/dev/config";
          const basePath = (process.env.VITE_BASE_PATH || "/").replace(/\/$/, "") || undefined;' \
                      --replace-fail 'ssr: false,' 'ssr: false,
            basename: basePath === "/" ? undefined : basePath,'
        '';

        # Don't run yarnInstallHook - we just want the build output
        dontYarnInstall = true;

        buildPhase = ''
          runHook preBuild
          yarn build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r build/client/* $out/
          runHook postInstall
        '';
      };
    in
    final.buildGoModule {
      pname = "koito";
      inherit version src;

      # Will compute on first build
      vendorHash = "sha256-W/+ByBlEPd4yIUD/E28q93fz6wYgvhwyBvJL8Fm1lNY=";

      env.CGO_ENABLED = "1";

      nativeBuildInputs = [ final.pkg-config ];
      buildInputs = [ final.vips ];

      ldflags = [
        "-s"
        "-w"
        "-X main.Version=${version}"
      ];

      subPackages = [ "cmd/api" ];

      # Bundle frontend and assets
      postInstall = ''
        mkdir -p $out/share/koito/client/build/client
        mkdir -p $out/share/koito/client/public

        # Copy frontend build to client/build/client/ (where Koito expects it)
        cp -r ${frontend}/* $out/share/koito/client/build/client/

        # Copy public assets to client/public/
        cp -r $src/client/public/* $out/share/koito/client/public/

        # Copy database migrations
        cp -r $src/db $out/share/koito/

        # Copy assets (default images, fonts for rewind generation)
        cp -r $src/assets $out/share/koito/

        # Rename binary
        mv $out/bin/api $out/bin/koito
      '';

      meta = with final.lib; {
        description = "ListenBrainz-compatible scrobbler";
        homepage = "https://github.com/gabehf/koito";
        license = licenses.agpl3Plus;
        platforms = platforms.linux;
      };
    };

  # Multi-scrobbler - scrobble from multiple sources to multiple clients
  # Upstream source with local subpath deployment fixes
  multi-scrobbler = (final.buildNpmPackage.override { nodejs = final.nodejs; }) {
    pname = "multi-scrobbler";
    version = "0.15.0";

    src = final.fetchFromGitHub {
      owner = "FoxxMD";
      repo = "multi-scrobbler";
      rev = "7dec9a39e6342a2d374766cfcce3b8d7094b608b";
      hash = "sha256-vhda31xPLxGmnaU/3AnsrcafPvSE1IIbuRmj6xlttjc=";
    };

    npmDepsHash = "sha256-M0F0YnQ35YEioMzt4lJiUM/Iqfrb7/zwUG/vFGl+JSY=";

    patches = [
      ../patches/multi-scrobbler-event-driven-sqlite-timestamps.patch
      ../patches/multi-scrobbler-auth-retry-wal.patch
    ];

    nodejs = final.nodejs;

    # One development-only Storybook add-on runs `npx only-allow pnpm` from
    # its install script, which cannot work in the offline npm cache and is not
    # needed by either production build. The remaining dependencies ship their
    # platform binaries through locked optional packages.
    npmFlags = [ "--ignore-scripts" ];
    # Reapply the repository's checked-in dependency compatibility patches;
    # this is the only root install hook required by the build.
    preBuild = "npm run postinstall";

    # Subpath deployment - set base URL for frontend build
    # Multi-scrobbler's vite.config.ts reads BASE_URL and sets Vite's `base` option
    env.BASE_URL = "https://localhost/scrobbler";
    # Use hash router for subpath deployment (avoids conflicts with reverse proxy path stripping)
    env.USE_HASH_ROUTER = "true";

    # Fix vite.config.ts to use pathname only (not full URL) for Vite's base option
    # This ensures assets work correctly when accessed via any hostname
    postPatch = ''
            substituteInPlace vite.config.ts \
              --replace-fail 'baseUrlStr = baseUrl.toString();' 'baseUrlStr = baseUrl.pathname + "/";'

            # Fix static file serving - serve dist directly instead of relying on ViteExpress
            substituteInPlace src/backend/server/index.ts \
              --replace-fail "//app.use(express.static(buildDir));" "app.use('/assets', express.static(path.resolve(projectRootDir, 'dist/assets'), { fallthrough: false }));
        app.use(express.static(path.resolve(projectRootDir, 'dist')));"
            # Don't let ViteExpress override the base path at runtime - we handle it at build time
            # This ensures Caddy can strip /scrobbler/ prefix and Express serves at /
            substituteInPlace src/backend/server/index.ts \
              --replace-fail "base: localDefined && local.pathname !== '/' ? local.toString() : '/'" "base: '/'"

            # Replace SchemaUtils.ts - skip runtime schema generation entirely
            # Return permissive schemas that accept any valid JSON
            cat > src/backend/utils/SchemaUtils.ts << 'SCHEMAEOF'
      export const createVegaGenerator = () => null;

      // Return a permissive schema that accepts any object
      // The pre-generated schemas exist but extracting sub-types is complex
      // Config validation will be lenient but the app will run
      export const getTypeSchemaFromConfigGenerator = (type: string): any => {
        return { type: "object", additionalProperties: true };
      }
      SCHEMAEOF
    '';

    # Skip docsite build - it has a separate package.json and isn't needed at runtime
    # Also skip schema generation which requires the docsite
    buildPhase = ''
      runHook preBuild
      npm run build:backend
      npm run build:frontend

      # Fix manifest.json - Vite doesn't update relative paths in public files
      # These need to be absolute so they work when served via Caddy's path stripping
      ${final.jq}/bin/jq '.icons |= map(.src = "/scrobbler/" + .src) | .start_url = "/scrobbler/"' \
        dist/manifest.json > dist/manifest.json.tmp && mv dist/manifest.json.tmp dist/manifest.json

      runHook postBuild
    '';

    # This custom build phase has no upstream check hook; keep the backend
    # regression suite explicit so it remains part of every package build.
    postBuild = ''
      npm run test:backend -- --timeout 10000
    '';

    # Don't run default npm install phase - we handle it
    dontNpmInstall = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/multi-scrobbler
      cp -r dist $out/lib/multi-scrobbler/
      cp -r node_modules $out/lib/multi-scrobbler/
      cp package.json $out/lib/multi-scrobbler/

      # Copy source for tsx runtime (some files are still loaded from src)
      cp -r src $out/lib/multi-scrobbler/

      mkdir -p $out/bin
      cat > $out/bin/multi-scrobbler <<EOF
      #!${final.runtimeShell}
      cd $out/lib/multi-scrobbler
      exec ${final.nodejs}/bin/node --import tsx src/backend/index.ts "\$@"
      EOF
      chmod +x $out/bin/multi-scrobbler

      runHook postInstall
    '';

    meta = with final.lib; {
      description = "Scrobble plays from multiple sources to multiple clients";
      homepage = "https://github.com/FoxxMD/multi-scrobbler";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  linear-cli =
    let
      version = "2.3.1";
      releaseBySystem = {
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-EVx8iUnPoJcSAIQDLrYyyvMnF2BwGShX+Rf6BL6YjXU=";
        };
        aarch64-linux = {
          target = "aarch64-unknown-linux-gnu";
          hash = "sha256-lXXKAe1P2zlnVDtRO6lz3ACLAwZoSQVhS4N9Sw8rMQI=";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          hash = "sha256-rDBWBpNK4GuLJJW0cuugDSwYiHtf8UZWTPCvwBJi1g0=";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          hash = "sha256-HMdv3hrTCFQ8xp+uZ7uuUdfGfsbLQ9KySfMLoZYV1HQ=";
        };
      };
      release =
        releaseBySystem.${final.stdenv.hostPlatform.system}
          or (throw "linear-cli: unsupported system ${final.stdenv.hostPlatform.system}");
      linear-bin = final.stdenvNoCC.mkDerivation {
        pname = "linear-cli-bin";
        inherit version;

        src = final.fetchurl {
          url = "https://github.com/schpet/linear-cli/releases/download/v${version}/linear-${release.target}.tar.xz";
          hash = release.hash;
        };

        sourceRoot = "linear-${release.target}";

        installPhase = ''
          runHook preInstall
          install -Dm755 linear $out/bin/linear
          runHook postInstall
        '';
      };
    in
    if final.stdenv.hostPlatform.isLinux then
      let
        linear-fhs = final.buildFHSEnv {
          name = "linear-cli-fhs";
          targetPkgs = _pkgs: [ ];
          runScript = "${linear-bin}/bin/linear";
        };
      in
      # This wrapper is deliberately trivial; avoid writeShellApplication's
      # ShellCheck build-time closure (the globally CPU-tuned package set would
      # otherwise rebuild the full Haskell dependency graph).
      final.writeShellScriptBin "linear" ''
        exec ${linear-fhs}/bin/linear-cli-fhs "$@"
      ''
    else
      final.stdenvNoCC.mkDerivation {
        pname = "linear-cli";
        inherit version;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          ln -s ${linear-bin}/bin/linear $out/bin/linear
          runHook postInstall
        '';

        meta = with final.lib; {
          description = "CLI for Linear issue tracker";
          homepage = "https://github.com/schpet/linear-cli";
          license = licenses.mit;
          mainProgram = "linear";
          platforms = builtins.attrNames releaseBySystem;
        };
      };
}
