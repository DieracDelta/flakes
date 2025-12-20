# Zig compiler overlays with znver3 CPU targeting
final: prev:
let
  inherit (prev) lib;

  customizeZig =
    name: drv:
    let
      extraFlags = if name == "zig_0_14" then [ "-fno-reference-trace" ] else [ ];
      myGlobalFlags = [ "-Dcpu=znver3" ] ++ extraFlags;

      finalZig = drv.overrideAttrs (old: {
        passthru = old.passthru // {
          hook = final.callPackage "${prev.path}/pkgs/development/compilers/zig/hook.nix" {
            zig = finalZig;
            globalBuildFlags = myGlobalFlags;
          };
          zig = finalZig;
        };
      });
    in
    finalZig;

  zigTargets = [
    "zig_0_13"
    "zig_0_14"
    "zig_0_15"
  ];
  validZigSets = builtins.filter (name: builtins.hasAttr name prev) zigTargets;
in
lib.genAttrs validZigSets (name: customizeZig name prev.${name})
