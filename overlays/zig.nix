_final: prev:
let
  inherit (prev) lib;
  isZen3Target = (prev.stdenv.hostPlatform.gcc.arch or null) == "znver3";

  # Override zig's default cpu flag from "baseline" to "znver3"
  # The new zig setup hook (post nixpkgs#473413) uses env.zig_default_cpu_flag
  # which gets substituted into setup-hook.sh via @zig_default_cpu_flag@
  customizeZig =
    drv:
    drv.overrideAttrs (old: {
      env = (old.env or { }) // {
        zig_default_cpu_flag = "-Dcpu=znver3";
      };
    });

  zigTargets = builtins.filter (
    name: name == "zig" || builtins.match "zig_[0-9]+_[0-9]+" name != null
  ) (builtins.attrNames prev);
in
lib.optionalAttrs isZen3Target (lib.genAttrs zigTargets (name: customizeZig prev.${name}))
