self: super: rec {
        rootbar = super.callPackage ./pkgs/rootbar { };
        grim = super.callPackage ./pkgs/grim { };
        slurp = super.callPackage ./pkgs/slurp { };
        wl-clipboard = super.callPackage ./pkgs/wl-clipboard { };
        clipman = super.callPackage ./pkgs/clipman { };
        deepfry = super.callPackage ./pkgs/deepfry {};
        imagemagick = super.callPackage ./pkgs/imagemagick {};
        wofi             = super.callPackage ./pkgs/wofi {};
        zathura_rice = super.callPackage ./pkgs/zathura_rice {};
      }
