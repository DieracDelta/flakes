sudo nix build  --extra-experimental-features flakes --extra-experimental-features nix-command .#darwinConfigurations.jrestivo-2.system -L || exit 1 # --show-trace
# sudo ./result/sw/bin/darwin-rebuild switch --flake $PWD
sudo ./result/activate || exit 1
