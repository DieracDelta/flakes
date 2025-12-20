# Python package overlays
# - Disable checks for faster builds
# - Fix broken packages
final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      # Python packages don't go through our stdenv overlay, so add the phase here
      disableCheckArgs =
        args:
        let
          existingPrePhases = args.prePhases or [ ];
        in
        args
        // {
          prePhases =
            if builtins.elem "disableChecksPhase" existingPrePhases then
              existingPrePhases
            else
              existingPrePhases ++ [ "disableChecksPhase" ];
          disableChecksPhase = ''
            unset doCheck
            unset doInstallCheck
            # Override Python-specific check phases to be no-ops
            pytestCheckPhase() { :; }
            pythonImportsCheckPhase() { :; }
          '';
        };

      buildPythonPackage = python-prev.buildPythonPackage // {
        __functor = self: args: python-prev.buildPythonPackage (python-final.disableCheckArgs args);
      };
      buildPythonApplication = python-prev.buildPythonApplication // {
        __functor = self: args: python-prev.buildPythonApplication (python-final.disableCheckArgs args);
      };

      # Package-specific fixes
      psycopg = python-prev.psycopg.overridePythonAttrs (oldAttrs: {
        propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ python-final.psycopg-pool ];
      });

      mutatormath = python-prev.mutatormath.overridePythonAttrs (old: {
        catchConflicts = false;
      });

      jeepney = python-prev.jeepney.overridePythonAttrs (old: {
        pythonImportsCheck = [ "jeepney" ];
      });

      fontparts = python-prev.fontparts.overridePythonAttrs (old: {
        catchConflicts = false;
        dontCheckRuntimeDeps = true;
      });

      ufoprocessor = python-prev.ufoprocessor.overridePythonAttrs (old: {
        catchConflicts = false;
        dontCheckRuntimeDeps = true;
      });

      afdko = python-prev.afdko.overridePythonAttrs (old: {
        dontCheckRuntimeDeps = true;
        catchConflicts = false;
      });

      img2pdf = python-prev.img2pdf.overridePythonAttrs (old: {
        src = final.fetchFromGitHub {
          owner = "josch";
          repo = "img2pdf";
          rev = "0.6.1";
          hash = "sha256-71u6ex+UAEFPDtR9QI8Ezah5zCorn4gMdAnzFz4blsI=";
        };
      });

      pyasn = python-prev.pyasn.overridePythonAttrs (old: {
        datasrc = old.datasrc.override {
          hash = "sha256-7zpaxDe5qHUy/ekOJLxKawjaPQnByrOVj+m2bsUqfdg=";
        };
      });

      debugpy = python-prev.debugpy.overrideAttrs (oldAttrs: {
        src = oldAttrs.src.override {
          hash = "sha256-eAiCtSJUqLASapxnYCyq1UCiGz6QmKQum7Vs3MoU1s8=";
        };
      });

      instructor = python-prev.instructor.overridePythonAttrs (old: {
        src = final.fetchFromGitHub {
          owner = "jxnl";
          repo = "instructor";
          tag = "v1.11.3";
          hash = "sha256-VWFrMgfe92bHUK1hueqJLHQ7G7ATCgK7wXr+eqrVWcw=";
        };
      });

      pypng = python-prev.pypng.overridePythonAttrs (old: {
        src = final.fetchFromGitLab {
          owner = "drj11";
          repo = "pypng";
          tag = "pypng-0.20231004.0";
          hash = "sha256-xNUI3yGfwmaccCxgljIZzgJ6YgNxcuOzCXDE7RFJP2I=";
        };
      });

      rank-bm25 = python-prev.rank-bm25.overridePythonAttrs (old: {
        src = final.fetchFromGitHub {
          owner = "dorianbrown";
          repo = "rank_bm25";
          tag = old.version;
          hash = "sha256-+BxQBflMm2AvCLAFFj52Jpkqn+KErwYXU1wztintgOg=";
        };
      });

      # Fix 404 error for 0.42.2 - pin to 0.41.2
      sqlalchemy-utils = python-prev.sqlalchemy-utils.overridePythonAttrs (old: rec {
        version = "0.41.2";
        src = final.fetchFromGitHub {
          owner = "kvesteri";
          repo = "sqlalchemy-utils";
          rev = version;
          hash = "sha256-jC8onlCiuzpMlJ3EzpzCnQ128xpkLzrZEuGWQv7pvVE=";
        };
      });

      # Fix opencv source directory name issue
      opencv4 = python-prev.opencv4.overrideAttrs (old: {
        postUnpack =
          builtins.replaceStrings
            [ "$NIX_BUILD_TOP/source/opencv_contrib" ]
            [ "$NIX_BUILD_TOP/${old.src.name}/opencv_contrib" ]
            old.postUnpack;
        preConfigure =
          builtins.replaceStrings
            [ "$NIX_BUILD_TOP/source/opencv_contrib" ]
            [ "$NIX_BUILD_TOP/${old.src.name}/opencv_contrib" ]
            old.preConfigure;
      });
    })
  ];
}
