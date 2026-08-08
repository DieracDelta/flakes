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
# All RAPIDS libs must use synchronized versions (26.06.x)
_: final: prev:
let
  # RAPIDS version - all components must match
  rapidsVersion = "26.06.00";

  # Treelite version and commit required by cuML 26.06.
  treeliteVersion = "4.7.0";

  # Helper for CUDA builds
  inherit (final.cudaPackages)
    backendStdenv
    cuda_nvcc
    cuda_cudart
    cuda_nvrtc
    cuda_cccl
    ;
  inherit (final.cudaPackages)
    libcublas
    libcusolver
    libcusparse
    libcurand
    libcufft
    libnvjitlink
    ;

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
    rev = "v26.06.00";
    hash = "sha256-m0BglaAxJPbwcN0PmaA6+db+ZWK5PSAkhktfh6JpKi8=";
  };

  # CPM.cmake - Package manager used by RAPIDS
  # Pre-fetched to avoid network access during build
  cpm-cmake = final.fetchurl {
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.42.0/CPM.cmake";
    hash = "sha256-ICC0/ELbpEgXmD4GNC5oLs/D0vSEpYHxHMVzH75Nzoo=";
  };

  # rapids_logger - Logging infrastructure for RAPIDS
  rapids-logger-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "rapids-logger";
    rev = "4c72b598f99c8aa06af49468b3fc82f3931c6bf6";
    hash = "sha256-yRvO/+SCJThzYvYrt0ZudJojFUfO21OlEIy5G4HjtJ0=";
  };

  # CCCL - CUDA C++ Core Libraries (Thrust, CUB, libcudacxx)
  cccl-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cccl";
    rev = "207502e57019cefacf6f21d3bb6045aeebef2a3e";
    hash = "sha256-S1GTG7cs6doTDTMfEWjLYDK4JId1xVjLaJ4kBn8AuO0=";
  };

  # NVTX - NVIDIA Tools Extension SDK
  nvtx-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "NVTX";
    rev = "69c9949150ac1c310758a304082228a36d5e4758";
    hash = "sha256-uB1HHLVoOO0rWOcOqfypdiveagnjDcQQZNP7xBHhCwE=";
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

  # cuVS 26.06 applies a CUDA 12/13 CCCL layout patch to CUTLASS 4.1.0
  # through its CPM override. Since the offline build supplies FetchContent an
  # already populated source, apply that upstream patch explicitly here.
  cuvs-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "cuvs";
    rev = "v${rapidsVersion}";
    hash = "sha256-wLlRppsdqr3/Dm65f25l/ZifWLXKMlW3OWUDBSblq1I=";
  };
  cutlass-unpatched-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "v4.1.0";
    hash = "sha256-ZY+6Tg/CC6fqvU764k6QNudYDpY+s8OQklG+1aXQuns=";
  };
  cutlass-src = final.applyPatches {
    name = "cutlass-4.1.0-cuvs-patched";
    src = cutlass-unpatched-src;
    patches = [
      "${cuvs-src}/cpp/cmake/patches/cutlass/Support-both-CUDA-12-and-13-cccl-header-locations.patch"
    ];
  };

  # nvForest is enabled by cuML's default CUML_ALGORITHMS=ALL. Supply its
  # synchronized source explicitly because FetchContent is fully offline.
  nvforest-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "nvforest";
    rev = "v${rapidsVersion}";
    hash = "sha256-e9oO8zN70TNPwPXCOhNuTe/mvmpyHKWpWxC4MjuqZIQ=";
  };

  # cuCollections - CUDA concurrent data structures
  cuco-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cuCollections";
    rev = "f517bbb1277753b1852dfd388993383e401eaa38";
    hash = "sha256-49U0kgEXi2v0MQ7ZnlhNMkNIzRZliTabxCD8Ik6TNqU=";
  };

  # dlpack - DLPack tensor exchange library (used by cuvs)
  dlpack-src = final.fetchFromGitHub {
    owner = "dmlc";
    repo = "dlpack";
    rev = "v0.8";
    hash = "sha256-IcfCoz3PfDdRetikc2MZM1sJFOyRgKonWMk21HPbrso=";
  };

  # Treelite source - pre-fetched for cuml Python build
  treelite-src = final.fetchFromGitHub {
    owner = "dmlc";
    repo = "treelite";
    rev = "74b25ecedb964ccac37d034860cc5c1224e73e91";
    hash = "sha256-6rMAmbxj+2OzNbkG2xmdedSaEdCID8sni0Xtay9r6hI=";
  };

  # mdspan - header-only library required by treelite
  mdspan-src = final.fetchFromGitHub {
    owner = "kokkos";
    repo = "mdspan";
    rev = "mdspan-0.6.0";
    hash = "sha256-bwE+NO/n9XsWOp3GjgLHz3s0JR0CzNDernfLHVqU9Z8=";
  };

  # GPUTreeShap - GPU SHAP values for tree models (used by cuml)
  gputreeshap-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "GPUTreeShap";
    rev = "93292317b23ef733f881c881865f5d5728dc2fea";
    hash = "sha256-uJZ5JidZANpn24Jk/oJyj9MluJAgGNBU9ZlYmJWVSiU=";
  };

  # cuda-python source - monorepo containing cuda-pathfinder, cuda-bindings, cuda-python
  # Using v12.9.5 which supports older Cython (v13.x requires Cython 3.2+)
  cuda-python-src = final.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cuda-python";
    rev = "v12.9.5";
    hash = "sha256-wdjytQiO3WaTGAa8balMThS87XCpdjbzQgG0QwkJbKE=";
  };

  # CUDA packages needed for cuda-bindings build
  cuda_profiler_api = final.cudaPackages.cuda_profiler_api;
  cuda_nvrtc_dev = final.lib.getDev cuda_nvrtc;

  # Get include outputs for CUDA packages (headers are in 'include' output, not 'dev')
  cudart_dev = final.lib.getDev cuda_cudart;
  nvrtc_include = cuda_nvrtc.include or (final.lib.getOutput "include" cuda_nvrtc);
  profiler_api_include =
    final.cudaPackages.cuda_profiler_api.include
      or (final.lib.getOutput "include" final.cudaPackages.cuda_profiler_api);
  nvml_include =
    final.cudaPackages.cuda_nvml_dev.include
      or (final.lib.getOutput "include" final.cudaPackages.cuda_nvml_dev);
  cufile_include =
    final.cudaPackages.libcufile.include
      or (final.lib.getOutput "include" final.cudaPackages.libcufile);

  # Merged CUDA home with all headers cuda-bindings needs
  # symlinkJoin doesn't properly merge include/ subdirs, so we do it manually
  cuda-merged-home = final.runCommand "cuda-merged-home-v6" { } ''
    mkdir -p $out/include $out/lib

    echo "DEBUG: cuda_nvcc = ${cuda_nvcc}"
    echo "DEBUG: cudart_dev = ${cudart_dev}"
    echo "DEBUG: nvrtc_include = ${nvrtc_include}"
    echo "DEBUG: profiler_api_include = ${profiler_api_include}"
    echo "DEBUG: nvml_include = ${nvml_include}"
    echo "DEBUG: cufile_include = ${cufile_include}"

    # Copy headers from each package explicitly
    echo "Copying from ${cuda_nvcc}/include/"
    cp -rn "${cuda_nvcc}/include/"* $out/include/ 2>/dev/null || true

    echo "Copying from ${cudart_dev}/include/"
    cp -rn "${cudart_dev}/include/"* $out/include/ 2>/dev/null || true

    echo "Copying from ${nvrtc_include}/include/"
    cp -rn "${nvrtc_include}/include/"* $out/include/ 2>/dev/null || true

    echo "Copying from ${profiler_api_include}/include/"
    cp -rn "${profiler_api_include}/include/"* $out/include/ 2>/dev/null || true

    echo "Copying from ${nvml_include}/include/"
    cp -rn "${nvml_include}/include/"* $out/include/ 2>/dev/null || true

    echo "Copying from ${cufile_include}/include/"
    cp -rn "${cufile_include}/include/"* $out/include/ 2>/dev/null || true

    # Verify critical headers exist
    echo "Checking for required headers..."
    for h in cuda.h cudaProfiler.h cuda_profiler_api.h nvrtc.h cuda_runtime.h; do
      if [ -f "$out/include/$h" ]; then
        echo "  Found: $h"
      else
        echo "  MISSING: $h" >&2
      fi
    done

    # Also copy libs if needed
    for pkg in ${cuda_nvcc} ${final.lib.getLib cuda_cudart} ${final.lib.getLib cuda_nvrtc}; do
      if [ -d "$pkg/lib" ]; then
        cp -rn "$pkg/lib/"* $out/lib/ 2>/dev/null || true
      fi
    done
  '';

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
    "-DFETCHCONTENT_SOURCE_DIR_NVFOREST=${nvforest-src}"
  ];

  # Patched RAPIDS lib for downstream Python builds - fixes broken cmake config paths
  # Issues fixed:
  # 1. CCCL header search uses NO_DEFAULT_PATH with broken Nix store path resolution
  # 2. INTERFACE_INCLUDE_DIRECTORIES references non-existent build-tree paths
  librmm-patched =
    pkg:
    final.runCommand "rapids-cmake-patched-${pkg.name}" { } ''
      cp -r ${pkg} $out
      chmod -R u+w $out

      # Fix all header-search.cmake files to remove restrictive search options
      for f in $(find $out -name "*-header-search.cmake"); do
        sed -i 's/NO_DEFAULT_PATH//' "$f"
        sed -i 's/NO_CMAKE_FIND_ROOT_PATH//' "$f"
        # Add the correct include path as a search location
        sed -i "s|PATHS|PATHS ${pkg}/include/rapids ${pkg}/include|" "$f"
      done

      # Fix any hardcoded build-tree paths in cmake configs
      # Replace /build/*/include references with the installed include path
      for f in $(find $out -name "*.cmake"); do
        sed -i 's|/build/[^;"]*/include|${pkg}/include|g' "$f"
      done
    '';
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
        rev = "74b25ecedb964ccac37d034860cc5c1224e73e91";
        hash = "sha256-6rMAmbxj+2OzNbkG2xmdedSaEdCID8sni0Xtay9r6hI=";
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
      hash = "sha256-rP3TXEtbvRjKEenL2DUFuuGN3ID8qNK2iavPZZqNi4s=";
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

    cmakeFlags = commonRapidsCmakeFlags;

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
      hash = "sha256-c09BzI+eB25M5yy8i2Dr3lf6TmACEQ41xFAfD/ImGYI=";
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
      "-DBUILD_PRIMS_BENCH=OFF"
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

    src = cuvs-src;

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
    ++ cudaLibAllOutputs libcurand
    ++ cudaLibAllOutputs libnvjitlink;

    cmakeFlags = commonRapidsCmakeFlags ++ [
      "-DBUILD_CUVS_BENCH=OFF"
      # cuCollections downloads RoaringBitmap fixtures by default even though
      # all consuming tests are disabled.
      "-DCUCO_DOWNLOAD_ROARING_TESTDATA=OFF"
      # cuVS' direct CPM packages bypass FetchContent's source-dir cache variables.
      "-DCPM_hnswlib_SOURCE=${hnswlib-src}"
      "-DCPM_dlpack_SOURCE=${dlpack-src}"
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
      hash = "sha256-OehfXlzpSuYdsZwhfGTWqRILaycnA8QSbxKbjG/+yY8=";
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
    ++ cudaLibAllOutputs libcufft
    ++ cudaLibAllOutputs libnvjitlink;

    cmakeFlags = commonRapidsCmakeFlags ++ [
      # Disable multi-GPU support; cumlprims_mg moved into cuML itself.
      "-DSINGLEGPU=ON"
      "-DCUCO_DOWNLOAD_ROARING_TESTDATA=OFF"
      "-DCPM_hnswlib_SOURCE=${hnswlib-src}"
      "-DCPM_dlpack_SOURCE=${dlpack-src}"
      "-DCPM_GPUTreeShap_SOURCE=${gputreeshap-src}"
      "-DCPM_nvforest_SOURCE=${nvforest-src}"
      "-DTreelite_ROOT=${final.treelite}"
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

  # Cython 3.2 is required by all RAPIDS 26.06 Python bindings.
  cython32 = final.python312Packages.cython.overrideAttrs (old: rec {
    version = "3.2.4";
    src = final.fetchFromGitHub {
      owner = "cython";
      repo = "cython";
      rev = version;
      hash = "sha256-8J5EcaQXexWEA+se5rCR06CwlEYao2XK5TnVNgFGHYQ=";
    };
  });

  # rapids-build-backend source
  rapids-build-backend-src = final.fetchFromGitHub {
    owner = "rapidsai";
    repo = "rapids-build-backend";
    rev = "v0.4.0";
    hash = "sha256-dT0jMoDqfKWRpjcTXvshKxnTjoTvQmd+F53ke2UDVGU=";
  };

  # ==========================================================================
  # Python bindings - added to python312Packages
  # ==========================================================================
  python312Packages = prev.python312Packages // {
    # rapids-build-backend - PEP 517 build backend for RAPIDS packages
    rapids-build-backend = final.python312Packages.buildPythonPackage {
      pname = "rapids-build-backend";
      version = "0.4.0";
      format = "pyproject";

      src = final.rapids-build-backend-src;

      build-system = [ final.python312Packages.setuptools ];

      propagatedBuildInputs = with final.python312Packages; [
        scikit-build-core
        packaging
        toml
        pyyaml
        tomlkit
      ];

      # Don't run tests since they require the full RAPIDS setup
      doCheck = false;
      # Skip runtime dependency check for rapids-dependency-file-generator
      # (not needed in Nix builds since we manage deps through Nix)
      pythonRemoveDeps = [ "rapids-dependency-file-generator" ];

      meta = with final.lib; {
        description = "PEP 517 build backend for RAPIDS packages";
        homepage = "https://github.com/rapidsai/rapids-build-backend";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # treelite Python bindings - wraps C library via ctypes
    # Uses format="other" to skip the custom build backend that tries to
    # rebuild the C library; we install the pure Python files directly
    # and point them at the pre-built C library.
    treelite = final.python312Packages.buildPythonPackage {
      pname = "treelite";
      version = treeliteVersion;
      format = "other";

      src = treelite-src;
      sourceRoot = "${treelite-src.name}/python";

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        scipy
        packaging
      ];

      dontUnpack = false;

      buildPhase = ''
                # Write version file
                echo '${treeliteVersion}' > treelite/VERSION

                # Point treelite to the pre-built C library
                cat > treelite/path_config.py << 'PYEOF'
        def get_custom_libpath():
            return "${final.treelite}/lib"
        PYEOF
      '';

      installPhase = ''
        mkdir -p $out/${final.python312.sitePackages}
        cp -r treelite $out/${final.python312.sitePackages}/
      '';

      pythonImportsCheck = [ "treelite" ];

      meta = with final.lib; {
        description = "Treelite Python bindings for tree model serialization";
        homepage = "https://github.com/dmlc/treelite";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # cuda-core 0.3.2 is the Pythonic CUDA API required by numba-cuda 0.22.
    # Use NVIDIA's CPython 3.12 wheel; this RAPIDS stack is desktop/x86_64-only.
    cuda-core = final.python312Packages.buildPythonPackage {
      pname = "cuda-core";
      version = "0.3.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/b2/75/cb52e7d8c44ef4bf1313251685adc0c6568d51b9790edf7a1ecdf0135394/cuda_core-0.3.2-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-EzirMk0ps6/N5iPEoSVxzW5052+g1VM9seNt+XiJnk4=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [ final.stdenv.cc.cc.lib ];
      propagatedBuildInputs = with final.python312Packages; [
        numpy
        final.python312Packages.cuda-bindings
      ];

      pythonImportsCheck = [ "cuda.core" ];
      autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];

      meta = with final.lib; {
        description = "Pythonic CUDA core API";
        homepage = "https://github.com/NVIDIA/cuda-python";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # numba-cuda restores numba.cuda, which was split out of current Numba.
    numba-cuda = final.python312Packages.buildPythonPackage {
      pname = "numba-cuda";
      version = "0.22.2";
      format = "wheel";

      src = final.fetchurl {
        url = "https://files.pythonhosted.org/packages/42/c5/f8771db9e643f1935f4bfe9f9c33c6cf425648103e3bc05659cd7356787c/numba_cuda-0.22.2-cp312-cp312-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
        hash = "sha256-jTTZXNWjUsHZVkUDrstJ2UAnTm/7Xa5Et45OTke4qfU=";
      };

      nativeBuildInputs = [ final.autoPatchelfHook ];
      buildInputs = [ final.stdenv.cc.cc.lib ];
      propagatedBuildInputs = with final.python312Packages; [
        numba
        packaging
        final.python312Packages.cuda-bindings
        final.python312Packages.cuda-core
        final.python312Packages.cuda-python
      ];

      pythonRelaxDeps = true;
      pythonImportsCheck = [ "numba.cuda" ];
      autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];

      meta = with final.lib; {
        description = "CUDA target for Numba";
        homepage = "https://github.com/NVIDIA/numba-cuda";
        license = licenses.bsd2;
        platforms = platforms.linux;
      };
    };

    # cuda-bindings 12.9 accepts cuda-pathfinder >=1.1,<2. Reuse nixpkgs'
    # current 1.x package so CuPy and the RAPIDS CUDA bindings share one copy.
    cuda-pathfinder = prev.python312Packages.cuda-pathfinder;

    # cuda-bindings - Python bindings for CUDA APIs
    cuda-bindings = final.python312Packages.buildPythonPackage {
      pname = "cuda-bindings";
      version = "12.9.5";
      format = "pyproject";

      src = cuda-python-src;
      sourceRoot = "${cuda-python-src.name}/cuda_bindings";

      build-system = with final.python312Packages; [
        setuptools
        final.cython32
        pyclibrary
      ];

      buildInputs = [
        cuda_cudart
        cuda_nvcc
        cuda_nvrtc
        cuda_profiler_api
      ];

      propagatedBuildInputs = [
        final.python312Packages.cuda-pathfinder
      ];

      # Set CUDA_HOME to merged directory with all CUDA headers
      env = {
        CUDA_HOME = "${cuda-merged-home}";
        CUDA_PATH = "${cuda-merged-home}";
      };

      # Increase Python recursion limit for complex Cython modules like _nvml.pyx
      # Also remove cufile bindings (not needed for RAPIDS and has API version issues)
      preBuild = ''
        # Create a sitecustomize.py to increase recursion limit
        mkdir -p $TMPDIR/sitecustomize_dir
        echo "import sys; sys.setrecursionlimit(10000)" > $TMPDIR/sitecustomize_dir/sitecustomize.py
        export PYTHONPATH="$TMPDIR/sitecustomize_dir:$PYTHONPATH"

        # Remove cufile bindings to avoid API version mismatch
        rm -f cuda/bindings/cufile.pyx cuda/bindings/cufile.pxd
        rm -f cuda/bindings/cycufile.pyx cuda/bindings/cycufile.pxd
        rm -f cuda/bindings/_bindings/cycufile.pyx cuda/bindings/_bindings/cycufile.pxd
        rm -rf cuda/bindings/_internal/cufile*.pyx cuda/bindings/_internal/cufile*.pxd
      '';

      pythonImportsCheck = [ "cuda.bindings" ];

      meta = with final.lib; {
        description = "Python bindings for CUDA";
        homepage = "https://github.com/NVIDIA/cuda-python";
        license = licenses.unfree; # NVIDIA proprietary
        platforms = platforms.linux;
      };
    };

    # cuda-python - Meta package combining cuda-bindings and cuda-pathfinder
    cuda-python = final.python312Packages.buildPythonPackage {
      pname = "cuda-python";
      version = "12.9.5";
      format = "pyproject";

      src = cuda-python-src;
      sourceRoot = "${cuda-python-src.name}/cuda_python";

      build-system = [ final.python312Packages.setuptools ];

      propagatedBuildInputs = [
        final.python312Packages.cuda-bindings
        final.python312Packages.cuda-core
        final.python312Packages.cuda-pathfinder
      ];

      pythonImportsCheck = [ "cuda" ];

      meta = with final.lib; {
        description = "NVIDIA CUDA Python bindings";
        homepage = "https://github.com/NVIDIA/cuda-python";
        license = licenses.unfree; # NVIDIA proprietary
        platforms = platforms.linux;
      };
    };

    # rmm Python bindings
    rmm = final.python312Packages.buildPythonPackage rec {
      pname = "rmm";
      version = rapidsVersion;
      format = "pyproject";

      src = final.fetchFromGitHub {
        owner = "rapidsai";
        repo = "rmm";
        rev = "v${version}";
        hash = "sha256-rP3TXEtbvRjKEenL2DUFuuGN3ID8qNK2iavPZZqNi4s=";
      };

      sourceRoot = "${src.name}/python/rmm";

      build-system = with final.python312Packages; [
        scikit-build-core
        final.cython32
      ];

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
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

      # Disable version constraints that don't apply in Nix
      pythonRelaxDeps = true;
      pythonRemoveDeps = [ "librmm" ]; # C++ lib handled through Nix, not pip

      env = {
        SKBUILD_CMAKE_ARGS = builtins.concatStringsSep ";" [
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCPM_DOWNLOAD_LOCATION=${cpm-cmake}"
          "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
          # Python extension targets otherwise see CUDA 12.9's older CCCL
          # headers before the CCCL 3.4 headers bundled by librmm.
          "-DCMAKE_CXX_FLAGS=-I${final.librmm}/include/rapids"
          "-Drmm_ROOT=${librmm-patched final.librmm}"
          "-DFIND_RMM_CPP=ON"
        ];
      };

      postUnpack = ''
        # Make source writable and add VERSION file
        chmod -R u+w $sourceRoot/../..
        echo '${version}' > $sourceRoot/../../VERSION
      '';

      postPatch = ''
        # Bypass rapids-build-backend, use scikit-build-core directly
        substituteInPlace pyproject.toml \
          --replace-fail 'build-backend = "rapids_build_backend.build"' 'build-backend = "scikit_build_core.build"' \
          --replace-fail '"rapids-build-backend>=0.4.0,<0.5.0",' ""
        # Create version file where scikit-build-core expects it
        echo '${version}' > rmm/VERSION

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
        hash = "sha256-c09BzI+eB25M5yy8i2Dr3lf6TmACEQ41xFAfD/ImGYI=";
      };

      sourceRoot = "${src.name}/python/pylibraft";

      build-system = with final.python312Packages; [
        scikit-build-core
        final.cython32
      ];

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
      ];

      buildInputs = [
        final.libraft
        final.librmm
        cuda_cudart
        cuda_cccl
      ]
      ++ cudaLibAllOutputs libcublas
      ++ cudaLibAllOutputs libcusolver
      ++ cudaLibAllOutputs libcusparse
      ++ cudaLibAllOutputs libcurand
      ++ cudaLibAllOutputs libcufft;

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        cuda-python
        final.python312Packages.rmm
      ];

      dontUseCmakeConfigure = true;
      pythonRelaxDeps = true;
      pythonRemoveDeps = [
        "libraft"
        "librmm"
      ];

      env = {
        SKBUILD_CMAKE_ARGS = builtins.concatStringsSep ";" [
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCPM_DOWNLOAD_LOCATION=${cpm-cmake}"
          "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
          "-DCMAKE_CXX_FLAGS=-I${final.librmm}/include/rapids"
          "-Draft_ROOT=${librmm-patched final.libraft}"
          "-Drmm_ROOT=${librmm-patched final.librmm}"
          "-DFIND_RAFT_CPP=ON"
        ];
      };

      postUnpack = ''
        chmod -R u+w $sourceRoot/../..
        echo '${version}' > $sourceRoot/../../VERSION
      '';

      postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail 'build-backend = "rapids_build_backend.build"' 'build-backend = "scikit_build_core.build"' \
          --replace-fail '"rapids-build-backend>=0.4.0,<0.5.0",' ""
        echo '${version}' > pylibraft/VERSION
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

      src = cuvs-src;

      sourceRoot = "${src.name}/python/cuvs";

      build-system = with final.python312Packages; [
        scikit-build-core
        final.cython32
      ];

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
      ];

      buildInputs = [
        final.libcuvs
        final.libraft
        final.librmm
        cuda_cudart
        cuda_cccl
      ]
      ++ cudaLibAllOutputs libcublas
      ++ cudaLibAllOutputs libcusolver
      ++ cudaLibAllOutputs libcusparse
      ++ cudaLibAllOutputs libcurand
      ++ cudaLibAllOutputs libcufft
      ++ cudaLibAllOutputs libnvjitlink;

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        cuda-python
        final.python312Packages.rmm
        final.python312Packages.pylibraft
      ];

      dontUseCmakeConfigure = true;
      pythonRelaxDeps = true;
      pythonRemoveDeps = [
        "libcuvs"
        "libraft"
        "librmm"
      ];

      env = {
        SKBUILD_CMAKE_ARGS = builtins.concatStringsSep ";" [
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCPM_DOWNLOAD_LOCATION=${cpm-cmake}"
          "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
          "-DCMAKE_CXX_FLAGS=-I${final.librmm}/include/rapids"
          "-Dcuvs_ROOT=${librmm-patched final.libcuvs}"
          "-Draft_ROOT=${librmm-patched final.libraft}"
          "-Drmm_ROOT=${librmm-patched final.librmm}"
          "-DFIND_CUVS_CPP=ON"
          "-DFETCHCONTENT_SOURCE_DIR_DLPACK=${dlpack-src}"
          "-DFETCHCONTENT_SOURCE_DIR_HNSWLIB=${hnswlib-src}"
          "-DCPM_dlpack_SOURCE=${dlpack-src}"
          "-DCPM_hnswlib_SOURCE=${hnswlib-src}"
          "-DFETCHCONTENT_SOURCE_DIR_CCCL=${cccl-src}"
          "-DFETCHCONTENT_SOURCE_DIR_NVTX3=${nvtx-src}"
          "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlog-src}"
          "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmt-src}"
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rapids-logger-src}"
          "-DFETCHCONTENT_SOURCE_DIR_NVIDIACUTLASS=${cutlass-src}"
          "-DFETCHCONTENT_SOURCE_DIR_CUCO=${cuco-src}"
          "-DCUCO_DOWNLOAD_ROARING_TESTDATA=OFF"
        ];
      };

      postUnpack = ''
        chmod -R u+w $sourceRoot/../..
        echo '${version}' > $sourceRoot/../../VERSION
      '';

      postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail 'build-backend = "rapids_build_backend.build"' 'build-backend = "scikit_build_core.build"' \
          --replace-fail '"rapids-build-backend>=0.4.0,<0.5.0",' ""
        echo '${version}' > cuvs/VERSION
      '';

      meta = with final.lib; {
        description = "Python bindings for CUDA Vector Search";
        homepage = "https://github.com/rapidsai/cuvs";
        license = licenses.asl20;
        platforms = platforms.linux;
      };
    };

    # cudf stub - provides empty types so cuml can import without the full cudf stack
    # cuml's internals unconditionally do `import cudf` for type checking, but we only
    # pass numpy/cupy arrays, so the stub types never match in isinstance checks.
    cudf = final.python312Packages.buildPythonPackage {
      pname = "cudf";
      version = rapidsVersion;
      format = "other";

      dontUnpack = true;

      buildPhase = ''
                mkdir -p cudf/core cudf/api/types cudf/pandas
                cat > cudf/__init__.py << 'PYEOF'
        """cudf stub - provides type stubs for cuml compatibility."""
        from cudf.core.dataframe import DataFrame
        from cudf.core.series import Series
        from cudf.core.index import Index
        from cudf.core.buffer import Buffer

        def concat(*args, **kwargs):
            raise NotImplementedError("cudf stub: concat not available")

        def from_pandas(*args, **kwargs):
            raise NotImplementedError("cudf stub: from_pandas not available")
        PYEOF

                cat > cudf/core/__init__.py << 'PYEOF'
        from cudf.core.dataframe import DataFrame
        from cudf.core.series import Series
        from cudf.core.index import Index
        from cudf.core.buffer import Buffer
        PYEOF

                cat > cudf/core/dataframe.py << 'PYEOF'
        class DataFrame:
            """Stub DataFrame type for cuml isinstance checks."""
            pass
        PYEOF

                cat > cudf/core/series.py << 'PYEOF'
        class Series:
            """Stub Series type for cuml isinstance checks."""
            null_count = 0
            pass
        PYEOF

                cat > cudf/core/index.py << 'PYEOF'
        class Index:
            """Stub Index type for cuml isinstance checks."""
            pass
        PYEOF

                cat > cudf/core/buffer.py << 'PYEOF'
        class Buffer:
            """Stub Buffer type for cuml isinstance checks."""
            pass
        PYEOF

                cat > cudf/api/__init__.py << 'PYEOF'
        PYEOF

                cat > cudf/api/types/__init__.py << 'PYEOF'
        def is_categorical_dtype(*args, **kwargs):
            return False
        def is_numeric_dtype(*args, **kwargs):
            return False
        PYEOF

                cat > cudf/pandas/__init__.py << 'PYEOF'
        PYEOF
      '';

      installPhase = ''
        mkdir -p $out/${final.python312.sitePackages}
        cp -r cudf $out/${final.python312.sitePackages}/
      '';

      meta = with final.lib; {
        description = "cudf stub for cuml import compatibility";
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
        hash = "sha256-OehfXlzpSuYdsZwhfGTWqRILaycnA8QSbxKbjG/+yY8=";
      };

      sourceRoot = "${src.name}/python/cuml";

      build-system = with final.python312Packages; [
        scikit-build-core
        final.cython32
      ];

      nativeBuildInputs = [
        final.cmake
        final.ninja
        cuda_nvcc
      ];

      buildInputs = [
        final.libcuml
        final.libcuvs
        final.libraft
        final.librmm
        final.treelite
        cuda_cudart
        cuda_cccl
      ]
      ++ cudaLibAllOutputs libcublas
      ++ cudaLibAllOutputs libcusolver
      ++ cudaLibAllOutputs libcusparse
      ++ cudaLibAllOutputs libcurand
      ++ cudaLibAllOutputs libcufft
      ++ cudaLibAllOutputs libnvjitlink;

      propagatedBuildInputs = with final.python312Packages; [
        numpy
        scipy
        scikit-learn
        numba
        final.python312Packages.numba-cuda
        cupy
        joblib
        packaging
        pandas
        rich
        cuda-python
        final.python312Packages.rmm
        final.python312Packages.pylibraft
        final.python312Packages.cuvs
        final.python312Packages.cudf # Stub types for import compatibility
        final.python312Packages.treelite # Tree model serialization
      ];

      dontUseCmakeConfigure = true;
      pythonRelaxDeps = true;
      # CUDA toolkit libraries, cuDF, nvForest, and Treelite are supplied by
      # Nix C++/Python inputs rather than CUDA-suffixed PyPI wheels.
      pythonRemoveDeps = [
        "cuda-toolkit"
        "libcuml"
        "cudf"
        "cupy-cuda13x"
        "nvforest"
        "nvidia-nvjitlink"
        "treelite"
      ];

      env = {
        SKBUILD_CMAKE_ARGS = builtins.concatStringsSep ";" [
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS-CMAKE=${rapids-cmake-src}"
          "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
          "-DCPM_DOWNLOAD_LOCATION=${cpm-cmake}"
          "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
          "-DCMAKE_CXX_FLAGS=-I${final.librmm}/include/rapids"
          "-Dcuml_ROOT=${librmm-patched final.libcuml}"
          "-Dcuvs_ROOT=${librmm-patched final.libcuvs}"
          "-Draft_ROOT=${librmm-patched final.libraft}"
          "-Drmm_ROOT=${librmm-patched final.librmm}"
          "-DFIND_CUML_CPP=ON"
          "-DSINGLEGPU=ON"
          # Pre-fetched sources for CPM dependencies
          "-DFETCHCONTENT_SOURCE_DIR_TREELITE=${treelite-src}"
          "-DFETCHCONTENT_SOURCE_DIR_MDSPAN=${mdspan-src}"
          "-DFETCHCONTENT_SOURCE_DIR_CCCL=${cccl-src}"
          "-DFETCHCONTENT_SOURCE_DIR_NVTX3=${nvtx-src}"
          "-DFETCHCONTENT_SOURCE_DIR_SPDLOG=${spdlog-src}"
          "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmt-src}"
          "-DFETCHCONTENT_SOURCE_DIR_RAPIDS_LOGGER=${rapids-logger-src}"
          "-DFETCHCONTENT_SOURCE_DIR_NVIDIACUTLASS=${cutlass-src}"
          "-DFETCHCONTENT_SOURCE_DIR_CUCO=${cuco-src}"
          "-DCUCO_DOWNLOAD_ROARING_TESTDATA=OFF"
          "-DFETCHCONTENT_SOURCE_DIR_DLPACK=${dlpack-src}"
          "-DFETCHCONTENT_SOURCE_DIR_HNSWLIB=${hnswlib-src}"
          "-DCPM_dlpack_SOURCE=${dlpack-src}"
          "-DCPM_hnswlib_SOURCE=${hnswlib-src}"
          "-DFETCHCONTENT_SOURCE_DIR_GPUTREESHAP=${gputreeshap-src}"
          "-DFETCHCONTENT_SOURCE_DIR_NVFOREST=${nvforest-src}"
          "-DCPM_GPUTreeShap_SOURCE=${gputreeshap-src}"
          "-DCPM_nvforest_SOURCE=${nvforest-src}"
          "-DTreelite_ROOT=${final.treelite}"
        ];
      };

      postUnpack = ''
        chmod -R u+w $sourceRoot/../..
        echo '${version}' > $sourceRoot/../../VERSION
      '';

      postPatch = ''
                substituteInPlace pyproject.toml \
                  --replace-fail 'build-backend = "rapids_build_backend.build"' 'build-backend = "scikit_build_core.build"' \
                  --replace-fail '"rapids-build-backend>=0.4.0,<0.5.0",' ""
                echo '${version}' > cuml/VERSION

                # Fix nvtx.py fallback: the @contextmanager-decorated function uses 'return'
                # instead of 'yield', causing TypeError at runtime when used as a decorator.
                # Replace with a proper no-op class that works as both decorator and context manager.
                cat > cuml/internals/nvtx.py << 'NVTXEOF'
        try:
            from nvtx import annotate
        except ImportError:
            class annotate:
                """No-op replacement for nvtx.annotate (decorator + context manager)."""
                def __init__(self, *args, **kwargs):
                    self._func = args[0] if (
                        len(kwargs) == 0 and len(args) == 1 and callable(args[0])
                    ) else None
                def __call__(self, *args, **kwargs):
                    if self._func is not None:
                        return self._func(*args, **kwargs)
                    if len(args) == 1 and callable(args[0]):
                        return args[0]
                    return self
                def __enter__(self):
                    return self
                def __exit__(self, *exc):
                    pass
        NVTXEOF
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
