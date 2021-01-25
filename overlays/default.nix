self: super: rec {
  deepfry = super.callPackage ./deepfry { };
  imagemagick = super.callPackage ./imagemagick { };
  /*firefox = super.callPackage ./firefox {}*/
  /*unchromium = super.callPackage ./unchromium {};*/
  hunter = super.callPackage ./hunter { };
}
