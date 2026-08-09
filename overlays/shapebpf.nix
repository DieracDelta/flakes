{ shapebpf }:
final: _prev:
let
  upstreamPackage = shapebpf.packages.${final.stdenv.hostPlatform.system}.default;
in
{
  shapebpf = upstreamPackage.overrideAttrs (old: {
    # The eBPF crate has its own vendor configuration. Cargo otherwise merges
    # it with the workspace's parent configuration and rejects the duplicated
    # aya Git source on current nixpkgs.
    preBuild = (old.preBuild or "") + ''
      cargo() {
        if [[ "$PWD" == */shapebpf-ebpf ]]; then
          mv ../.cargo/config.toml ../.cargo/config.workspace.toml
          command cargo "$@"
          local cargo_status=$?
          mv ../.cargo/config.workspace.toml ../.cargo/config.toml
          return "$cargo_status"
        fi
        command cargo "$@"
      }
    '';
  });
}
