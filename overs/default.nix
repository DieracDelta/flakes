self: super: rec {
  deepfry = super.callPackage ./pkgs/deepfry { };
  imagemagick = super.callPackage ./pkgs/imagemagick { };
}
