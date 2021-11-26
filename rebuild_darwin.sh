sudo nix build  .#darwinConfigurations.jrestivo-2.system
./result/sw/bin/darwin-rebuild switch --flake $PWD 
