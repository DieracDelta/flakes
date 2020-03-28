self: super: rec {
	      rootbar = super.callPackage ./pkgs/rootbar { };
	      grim = super.callPackage ./pkgs/grim { };
	      slurp = super.callPackage ./pkgs/slurp { };
	      wl-clipboard = super.callPackage ./pkgs/wl-clipboard { };
	      clipman = super.callPackage ./pkgs/clipman { };
	      opam2nix = super.callPackage ./pkgs/opam2nix {};
	      bap = super.callPackage ./pkgs/bap {};
	      deepfry = super.callPackage ./pkgs/deepfry {};
	      imagemagick = super.callPackage ./pkgs/imagemagick {};
}
