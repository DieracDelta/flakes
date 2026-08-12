{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.bpftop;
in
{
  options.programs.bpftop = {
    enable = lib.mkEnableOption "bpftop process monitor";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.bpftop.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.bpftop.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "The bpftop package to wrap.";
    };
  };

  config = lib.mkIf cfg.enable {
    security.wrappers.bpftop = {
      source = "${cfg.package}/bin/bpftop";
      owner = "root";
      group = "root";
      capabilities = "cap_bpf,cap_perfmon,cap_sys_resource,cap_dac_override,cap_sys_admin=eip";
    };
  };
}
