# RAPIDS GPU Computing Stack for cuML
# Provides GPU-accelerated machine learning algorithms (clustering, etc.)
#
# Dependency chain:
#   CUTLASS (already in nixpkgs)
#   → librmm (RAPIDS Memory Manager)
#   → libraft (ML Primitives)
#   → libcuvs (Vector Search)
#   → libcuml (ML Algorithms)
#   → cuml (Python bindings)
#
# All RAPIDS libs must use synchronized versions (25.06.x)
_:
final: prev:
let
  # RAPIDS version - all components must match
  rapidsVersion = "25.06.00";

  # Treelite version required by cuML
  treeliteVersion = "4.4.1";

  # Helper for CUDA builds
  inherit (final.cudaPackages) backendStdenv cuda_nvcc cuda_cudart cuda_nvrtc cuda_cccl;
  inherit (final.cudaPackages) libcublas libcusolver libcusparse libcurand libcufft;

  # Helper to get all necessary outputs for CUDA libraries
  # CMake's FindCUDAToolkit needs both headers (dev) and libraries (lib)
  cudaLibAllOutputs = pkg: [
    (final.lib.getDev pkg)
    (final.lib.getLib pkg)
  ];

  # rapids-cmake - CMake infrastructure for RAPIDS projects
  # Pre-fetched to avoid network access during build
  rapids-cmake-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "rapids-cmake";
    rev = "branch-25.06";
    hash = "sha256-q/K+99wPemBusvdbBKFomcVNckGR/FCHIMi6Jgts08w=";
  };

  # CPM.cmake - Package manager used by RAPIDS
  # Pre-fetched to avoid network access during build
  cpm-cmake = final.fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.0/CPM.cmake";
    hash = "sha256-ezVPOll2xGJsh2hQyTlE5SyD7FmhWa5d5b55g/Dheio=";
  };

  # rapids_logger - Logging infrastructure for RAPIDS
  rapids-logger-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "rapids-logger";
    rev = "46070bb255482f0782ca840ae45de9354380e298";
    hash = "sha256-/K5/j/1czaOs5G06Gpd+I+3OTDAa6Z+6tS0VW1+yEcI=";
  };

  # CCCL - CUDA C++ Core Libraries (Thrust, CUB, libcudacxx)
  cccl-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cccl";
    rev = "e80fa6c8c53c1d868b46571f3335c3964a63e816";
    hash = "sha256-MT32GVf+m3gMWsBs0SBnRaq+OHs2VZA+AZpD6rbBJys=";
  };

  # NVTX - NVIDIA Tools Extension SDK
  nvtx-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "NVTX";
    rev = "4808eeda29bb6dcfd38291d1a8ea280b48562c57";
    hash = "sha256-2LDfCm+kOZsL9QO63QuwesvTGs+DmtOmv36/BKN6PGY=";
  };

  # spdlog - Fast C++ logging library (required by rapids_logger)
  spdlog-src = final.fetchFromGitHub {
    owner = "gabime";
    repo = "spdlog";
    rev = "27cb4c76708608465c413f6d0e6b8d99a4d84302";
    hash = "sha256-F7khXbMilbh5b+eKnzcB0fPPWQqUHqAYPWJb83OnUKQ=";
  };

  # fmt - Format library (required by spdlog)
  fmt-src = final.fetchFromGitHub {
    owner = "fmtlib";
    repo = "fmt";
    rev = "0c9fce2ffefecfdce794e1859584e25877b7b592";
    hash = "sha256-IKNt4xUoVi750zBti5iJJcCk3zivTt7nU12RIf8pM+0=";
  };

  # CUTLASS - CUDA Templates for Linear Algebra Subroutines
  # Version required by raft
  cutlass-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "v3.5.1";
    hash = "sha256-sTGYN+bjtEqQ7Ootr/wvx3P9f8MCDSSj3qyCWjfdLEA=";
  };

  # cuCollections - CUDA concurrent data structures
  cuco-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cuCollections";
    rev = "f5e43ce27f33e7e98de16f712be9370a797f8c73";
    hash = "sha256-jog2ze2hdmK4wYKmGYjj9ID1RICDdUTleiCgQattMPY=";
  };

  # dlpack - DLPack tensor exchange library (used by cuvs)
  dlpack-src = final.fetchFromGitHub {
    owner = "dmlc";
    repo = "dlpack";
    rev = "v0.8";
    hash = "sha256-IcfCoz3PfDdRetikc2MZM1sJFOyRgKonWMk21HPbrso=";
  };

  # GPUTreeShap - GPU SHAP values for tree models (used by cuml)
  gputreeshap-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "GPUTreeShap";
    rev = "9382a8af94c0863de0944e65199a16fdf5f96a6d";
    hash = "sha256-K3gG8K8ifk7Bb552ZsIg/lrpFwc9UIZQGcf+E3iUSjM=";
  };

  # hnswlib - Approximate nearest neighbor search (used by cuvs)
  # cuvs requires a patched version with templated InnerProductSpace/L2Space
  hnswlib-src =
    let
      base = final.fetchFromGitHub {
        owner = "nmslib";
        repo = "hnswlib";
        rev = "v0.7.0";
        hash = "sha256-XXz0NIQ5dCGwcX2HtbK5NFTalP0TjLO6ll6TmH3oflI=";
      };
    in
    final.runCommand "hnswlib-patched" { } ''
      cp -r ${base} $out
      chmod -R u+w $out
      cd $out
      patch -p1 < ${../patches/hnswlib-cuvs.patch}
    '';

  # Common CMake flags for RAPIDS builds
  commonRapidsCmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DBUILD_BENCHMARKS=OFF"
    # Use only modern GPU architectures (75+) that fully support double atomics
    # and avoid deprecated pre-75 architectures
    "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
    # Point FetchContent to pre-fetched rapids-cmake
    "-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    # Point to pre-fetched CPM.cmake
    "-DCPM_DOWNLOAD_LOCATION=${cpm-cmake}"
    # Pre-fetched CPM dependencies
    "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rapids-logger-src}"
    "-DFETCHCONTENT_SOURCE_DIR_CCCL=${cccl-src}"
    "-DFETCHCONTENT_SOURCE_DIR_NVTX3=${nvtx-src}"
    "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlog-src}"
    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmt-src}"
    "-DFETCHCONTENT_SOURCE_DIR_NVIDIACUTLASS=${cutlass-src}"
    "-DFETCHCONTENT_SOURCE_DIR_CUCO=${cuco-src}"
    "-DFETCHCONTENT_SOURCE_DIR_DLPACK=${dlpack-src}"
    "-DFETCHCONTENT_SOURCE_DIR_HNSWLIB=${hnswlib-src}"
    "-DFETCHCONTENT_SOURCE_DIR_GPUTREESHAP=${gputreeshap-src}"
  ];
in
{
  # ==========================================================================
  # Treelite - Universal model serialization for tree-based models
  # Required by cuML's Forest Inference Library (FIL)
  # ==========================================================================
  treelite =
    let
      # mdspan - header-only library required by treelite
      mdspan-src = final.fetchFromGitHub {
        owner = "kokkos";
        repo = "mdspan";
        rev = "mdspan-0.6.0";
        hash = "sha256-bwE+NO/n9XsWOp3GjgLHz3s0JR0CzNDernfLHVqU9Z8=";
      };
    in
    final.stdenv.mkDerivation rec {
      pname = "treelite";
      version = treeliteVersion;

      src = final.fetchFromGitHub {
        owner = "dmlc";
        repo = "treelite";
        rev = version;
        hash = "sha256-Jai4nhRczkQjEf8Eib5ffPRAaLNpMFAgXsoXOIHuYSw=";
      };

      nativeBuildInputs = [
        final.cmake
        final.ninja
      ];

      buildInputs = [
        final.nlohmann_json
        final.rapidjson
      ];

      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DBUILD_CPP_TEST=OFF"
        "-DUSE_OPENMP=ON"
        # Point FetchContent to pre-fetched mdspan
        "-DFETCHCONTENT_SOURCE_DIR_MDSPAN=${mdspan-src}"
        "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
      ];

      meta = with final.lib; {
        description = "Universal model exchange and inference library for tree-based models";
        homepage = "https://github.com/dmlc/treelite";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

  # ==========================================================================
  # librmm - RAPIDS Memory Manager
  # Provides GPU memory allocation, pooling, and management
  # ==========================================================================
  librmm = backendStdenv.mkDerivation rec {
    pname = "rmm";
    version = rapidsVersion;

    src = final.fetchFromGitHub {
      owner = "rapidsai";
      repo = "rmm";
      rev = "v${version}";
      hash = "sha256-wxOlM37EkhHSPhdT/vWYlTeWWvO43i169M11VWVYbp0=";
    };

    # CMakeLists.txt is in cpp/ subdirectory
    sourceRoot = "${src.name}/cpp";

    nativeBuildInputs = [
      final.cmake
      final.ninja
      cuda_nvcc
    ];

    buildInputs = [
      cuda_cudart
      cuda_nvrtc
      cuda_cccl # NVIDIA C++ Core Libraries (Thrust, CUB, libcudacxx)
      final.spdlog
      final.fmt
    ];

    cmakeFlags = commonRapidsCmakeFlags ++ [
      "-DRMM_BUILD_TESTS=OFF"
      "-DRMM_BUILD_BENCHMARKS=OFF"
    ];

    # Need to copy VERSION file for rapids_config.cmake
    preConfigure = ''
      cp ../VERSION .
    '';

    meta = with final.lib; {
      description = "RAPIDS Memory Manager - GPU memory allocation and management";
      homepage = "https://github.com/rapidsai/rmm";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  # ==========================================================================
  # libraft - RAPIDS ML Primitives
  # Core algorithms for clustering, nearest neighbors, etc.
  # ==========================================================================
  libraft = backendStdenv.mkDerivation rec {
    pname = "raft";
    version = rapidsVersion;

    src = final.fetchFromGitHub {
      owner = "rapidsai";
      repo = "raft";
      rev = "v${version}";
      hash = "sha256-Ch7UTPI2xvo4j8mhpsPP+0gVSagd6EYj2sbOE0ujZ4Y=";
    };

    sourceRoot = "${src.name}/cpp";

    nativeBuildInputs = [
      final.cmake
      final.ninja
      cuda_nvcc
      final.git # Required for rapids-cmake patch generation
      final.python3 # Required by CUTLASS CMakeLists.txt
    ];

    buildInputs = [
      final.librmm
      cuda_cudart
      cuda_nvrtc
      cuda_cccl
      final.cudaPackages.cutlass
      final.spdlog
      final.fmt
    ]
    # Include both dev and lib outputs for CUDA libraries
    # so FindCUDAToolkit can create the CUDA::* targets
    ++ cudaLibAllOutputs libcublas
    ++ cudaLibAllOutputs libcusolver
    ++ cudaLibAllOutputs libcusparse
    ++ cudaLibAllOutputs libcurand;

    cmakeFlags = commonRapidsCmakeFlags ++ [
      "-DRAFT_BUILD_TESTS=OFF"
      "-DRAFT_BUILD_BENCHMARKS=OFF"
      "-DRAFT_COMPILE_LIBRARY=ON"
    ];

    preConfigure = ''
      cp ../VERSION .
    '';

    meta = with final.lib; {
      description = "RAPIDS ML primitives library";
      homepage = "https://github.com/rapidsai/raft";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  # ==========================================================================
  # libcuvs - CUDA Vector Search
  # GPU-accelerated similarity search and clustering
  # ==========================================================================
  libcuvs = backendStdenv.mkDerivation rec {
    pname = "cuvs";
    version = rapidsVersion;

    src = final.fetchFromGitHub {
      owner = "rapidsai";
      repo = "cuvs";
      rev = "v${version}";
      hash = "sha256-kuxhXfqeDM/uZs34BHylFvF164zLEHVMH4WeOjtW/3g=";
    };

    sourceRoot = "${src.name}/cpp";

    nativeBuildInputs = [
      final.cmake
      final.ninja
      cuda_nvcc
      final.git # Required for rapids-cmake patch generation
      final.python3 # Required by CUTLASS CMakeLists.txt
    ];

    buildInputs = [
      final.libraft
      final.librmm
      cuda_cudart
      cuda_nvrtc
      cuda_cccl
      final.spdlog
      final.fmt
    ]
    ++ cudaLibAllOutputs libcublas
    ++ cudaLibAllOutputs libcusolver
    ++ cudaLibAllOutputs libcusparse
    ++ cudaLibAllOutputs libcurand;

    cmakeFlags = commonRapidsCmakeFlags ++ [
      "-DCUVS_BUILD_TESTS=OFF"
      "-DCUVS_BUILD_BENCHMARKS=OFF"
      # Disable multi-GPU support (NCCL) - not needed for single-GPU clustering
      "-DBUILD_MG_ALGOS=OFF"
    ];

    preConfigure = ''
      cp ../VERSION .
    '';

    meta = with final.lib; {
      description = "CUDA Vector Search - GPU-accelerated similarity search";
      homepage = "https://github.com/rapidsai/cuvs";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  # ==========================================================================
  # libcuml - cuML C++ library
  # GPU-accelerated machine learning algorithms
  # ==========================================================================
  libcuml = backendStdenv.mkDerivation rec {
    pname = "cuml";
    version = rapidsVersion;

    src = final.fetchFromGitHub {
      owner = "rapidsai";
      repo = "cuml";
      rev = "v${version}";
      hash = "sha256-B4bi/zCNlm2HfD8Xdm8c55GFYiTqwl/qV1nSQoEyOUE=";
    };

    sourceRoot = "${src.name}/cpp";

    nativeBuildInputs = [
      final.cmake
      final.ninja
      cuda_nvcc
      final.git # Required for rapids-cmake patch generation
      final.python3 # Required by CUTLASS CMakeLists.txt
    ];

    buildInputs = [
      final.libcuvs
      final.libraft
      final.librmm
      final.treelite
      cuda_cudart
      cuda_nvrtc
      cuda_cccl
      final.spdlog
      final.fmt
    ]
    ++ cudaLibAllOutputs libcublas
    ++ cudaLibAllOutputs libcusolver
    ++ cudaLibAllOutputs libcusparse
    ++ cudaLibAllOutputs libcurand
    ++ cudaLibAllOutputs libcufft;

    cmakeFlags = commonRapidsCmakeFlags ++ [
      "-DCUML_BUILD_TESTS=OFF"
      "-DCUML_BUILD_BENCHMARKS=OFF"
      # Disable multi-GPU support (avoids cumlprims_mg dependency)
      "-DSINGLEGPU=ON"
      "-DENABLE_CUMLPRIMS_MG=OFF"
      # Disable tests and benchmarks (avoids GTest/gbench dependencies)
      "-DBUILD_CUML_TESTS=OFF"
      "-DBUILD_CUML_MG_TESTS=OFF"
      "-DBUILD_PRIMS_TESTS=OFF"
      "-DBUILD_CUML_EXAMPLES=OFF"
      "-DBUILD_CUML_BENCH=OFF"
    ];

    preConfigure = ''
      cp ../VERSION .
    '';

    meta = with final.lib; {
      description = "cuML - GPU-accelerated machine learning algorithms";
      homepage = "https://github.com/rapidsai/cuml";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  };

  # ==========================================================================
  # Python bindings - added to python312Packages
  # ==========================================================================
  python312Packages = prev.python312Packages // {
    # rmm Python bindings
    rmm = final.python312Packages.buildPythonPackage rec {
      pname = "rmm";
      version = rapidsVersion;
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "rapidsai";
        repo = "rmm";
        rev = "v${version}";
        hash = "sha256-wxOlM37EkhHSPhdT/vWYlTeWWvO43i169M11VWVYbp0=";
      };

      sourceRoot = "${src.name}/python/rmm";

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
        final.python312Packages.scikit-build-core
        final.python312Packages.cython
      ];

      buildInputs = [
        final.librmm
        cuda_cudart
        cuda_cccl
      ];

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        cuda-python
      ];

      dontUseCmakeConfigure = true;

      preBuild = ''
        export SKBUILD_CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
      '';

      meta = with final.lib; {
        description = "Python bindings for RAPIDS Memory Manager";
        homepage = "https://github.com/rapidsai/rmm";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # pylibraft Python bindings
    pylibraft = final.python312Packages.buildPythonPackage rec {
      pname = "pylibraft";
      version = rapidsVersion;
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "rapidsai";
        repo = "raft";
        rev = "v${version}";
        hash = "sha256-Ch7UTPI2xvo4j8mhpsPP+0gVSagd6EYj2sbOE0ujZ4Y=";
      };

      sourceRoot = "${src.name}/python/pylibraft";

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
        final.python312Packages.scikit-build-core
        final.python312Packages.cython
      ];

      buildInputs = [
        final.libraft
        final.librmm
        cuda_cudart
        cuda_cccl
      ];

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        cuda-python
        final.python312Packages.rmm
      ];

      dontUseCmakeConfigure = true;

      preBuild = ''
        export SKBUILD_CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
      '';

      meta = with final.lib; {
        description = "Python bindings for RAFT ML primitives";
        homepage = "https://github.com/rapidsai/raft";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # cuvs Python bindings
    cuvs = final.python312Packages.buildPythonPackage rec {
      pname = "cuvs";
      version = rapidsVersion;
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "rapidsai";
        repo = "cuvs";
        rev = "v${version}";
        hash = "sha256-kuxhXfqeDM/uZs34BHylFvF164zLEHVMH4WeOjtW/3g=";
      };

      sourceRoot = "${src.name}/python/cuvs";

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
        final.python312Packages.scikit-build-core
        final.python312Packages.cython
      ];

      buildInputs = [
        final.libcuvs
        final.libraft
        final.librmm
        cuda_cudart
        cuda_cccl
      ];

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        cuda-python
        final.python312Packages.rmm
        final.python312Packages.pylibraft
      ];

      dontUseCmakeConfigure = true;

      preBuild = ''
        export SKBUILD_CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
      '';

      meta = with final.lib; {
        description = "Python bindings for CUDA Vector Search";
        homepage = "https://github.com/rapidsai/cuvs";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # cuml Python bindings
    cuml = final.python312Packages.buildPythonPackage rec {
      pname = "cuml";
      version = rapidsVersion;
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "rapidsai";
        repo = "cuml";
        rev = "v${version}";
        hash = "sha256-B4bi/zCNlm2HfD8Xdm8c55GFYiTqwl/qV1nSQoEyOUE=";
      };

      sourceRoot = "${src.name}/python/cuml";

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
        final.python312Packages.scikit-build-core
        final.python312Packages.cython
      ];

      buildInputs = [
        final.libcuml
        final.libcuvs
        final.libraft
        final.librmm
        cuda_cudart
        cuda_cccl
      ];

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        scipy
        scikit-learn
        numba
        cupy
        joblib
        final.python312Packages.rmm
        final.python312Packages.pylibraft
        final.python312Packages.cuvs
      ];

      dontUseCmakeConfigure = true;

      preBuild = ''
        export SKBUILD_CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
      '';

      # Skip tests during build
      doCheck = false;

      pythonImportsCheck = [ "cuml" ];

      meta = with final.lib; {
        description = "cuML - GPU-accelerated machine learning for Python";
        homepage = "https://github.com/rapidsai/cuml";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };
  };

  # Expose cuml at top level for convenience
  cuml = final.python312Packages.cuml;
}
