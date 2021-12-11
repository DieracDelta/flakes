sudo nix build  .#darwinConfigurations.jrestivo-2.system -L
./result/sw/bin/darwin-rebuild switch --flake $PWD 
