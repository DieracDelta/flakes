{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.03";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.jrestivo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # ({ pkgs, ... }: {
        # boot.isContainer = true;

        # # Let 'nixos-version --json' know about the Git revision
        # # of this flake.
        # system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

        # # Network configuration.
        # networking.useDHCP = false;
        # networking.firewall.allowedTCPPorts = [ 80 ];
        # })
      ];
    };

  };
}
