{
  config,
  pkgs,
  lib,
  nixpkgs-stable,
  ...
}:
let
  cfg = config.custom_modules.runner_vms;
  # Use vanilla nixpkgs for github-runner to avoid znver3 dotnet source build
  stablePkgs = import nixpkgs-stable { system = "x86_64-linux"; };
  scriptsDir = "/home/jrestivo/dev/runners_deployment/scripts";
  ghRepo = "DieracDelta/WeebTogether";

  commonPath = lib.makeBinPath (with pkgs; [
    bash gh jq docker coreutils gnugrep procps curl
  ]);

  # Refresh the token file with a fresh registration token via gh CLI
  refreshTokenScript = pkgs.writeShellScript "refresh-runner-token" ''
    export PATH="${commonPath}:$PATH"
    export HOME="/home/jrestivo"
    TOKEN=$(gh api --method POST "repos/${ghRepo}/actions/runners/registration-token" --jq '.token')
    printf '%s' "$TOKEN" > /var/lib/github-runner/token
  '';

  idleCheckScript = pkgs.writeShellScript "runner-idle-check" ''
    export PATH="${commonPath}:$PATH"
    export HOME="/home/jrestivo"
    exec "${scriptsDir}/idle-check.sh"
  '';
in
{
  options.custom_modules.runner_vms.enable = lib.mkOption {
    description = "Enable CI runner VM orchestration: lightweight GitHub Actions runner + idle auto-shutdown.";
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    # Orchestrator runner via nixpkgs github-runners module
    services.github-runners.orchestrator = {
      enable = true;
      url = "https://github.com/${ghRepo}";
      tokenFile = "/var/lib/github-runner/token";
      name = "linux-orchestrator";
      extraLabels = [ "linux-self-hosted" ];
      replace = true;
      user = "jrestivo";
      group = "users";
      package = stablePkgs.github-runner;
      extraPackages = with pkgs; [ bash docker gh jq curl coreutils gnugrep procps ];
      serviceOverrides = {
        ProtectHome = false;
      };
    };

    # Refresh the token file before the runner's own configure script runs
    systemd.services.github-runner-orchestrator.serviceConfig.ExecStartPre = lib.mkBefore [
      "+${refreshTokenScript}"
    ];

    # Idle monitor: shuts down VMs after 2 hours of inactivity
    systemd.services.runner-idle-monitor = {
      description = "Check if CI runner VMs are idle and shut them down";
      serviceConfig = {
        Type = "oneshot";
        User = "jrestivo";
        ExecStart = idleCheckScript;
      };
    };

    systemd.timers.runner-idle-monitor = {
      description = "Periodically check CI runner VM idle status";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/2";
        Persistent = true;
      };
    };
  };
}
