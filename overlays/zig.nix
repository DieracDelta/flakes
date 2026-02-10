final: prev:
let
  inherit (prev) lib;

  # Override zig's default cpu flag from "baseline" to "znver3"
  # The new zig setup hook (post nixpkgs#473413) uses env.zig_default_cpu_flag
  # which gets substituted into setup-hook.sh via @zig_default_cpu_flag@
  customizeZig =
    name: drv:
    drv.overrideAttrs (old: {
      env = (old.env or { }) // {
        zig_default_cpu_flag = "-Dcpu=znver3";
      };
    });

  zigTargets = [
    "zig_0_13"
    "zig_0_14"
    "zig_0_15"
  ];
  validZigSets = builtins.filter (name: builtins.hasAttr name prev) zigTargets;
in
lib.genAttrs validZigSets (name: customizeZig name prev.${name})
