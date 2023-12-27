sudo nix build  .#darwinConfigurations.jrestivo-2.system -L # --show-trace
# sudo ./result/sw/bin/darwin-rebuild switch --flake $PWD
sudo ./result/activate
