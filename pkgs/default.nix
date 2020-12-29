self: super: rec {
  deepfry = super.callPackage ./deepfry { };
  imagemagick = super.callPackage ./imagemagick { };
}
