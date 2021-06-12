self: super: rec {
  deepfry = super.callPackage ./deepfry { };
  imagemagick = super.callPackage ./imagemagick { };
  /*firefox = super.callPackage ./firefox {}*/
  /*unchromium = super.callPackage ./unchromium {};*/
  hunter = super.callPackage ./hunter { };
  trezor-suite = super.callPackage ./trezor-suite { };
  /*nixFlakes = super.callPackage ./nixFlakes { };*/
  #vendor-reset = super.callPackage ./vendor-reset { kernel = super.linuxPackages_5_10.kernel; };
}
