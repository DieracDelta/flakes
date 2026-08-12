final: prev:
let
  # Bootstrap with nixpkgs' build-time fetcher: Nix cannot resolve a
  # pijul+ flake input until this plugin is already installed and loaded.
  source = prev.fetchpijul {
    url = "https://office-desktop.tail5ca7.ts.net:7443/jrestivo/nix-plugin-pijul";
    channel = "main";
    state = "BZFN2RREPEL2MGZWN7AX7O3ZVCBD7K4VQT7CSV6WA2DO2Z6DLK2AC";
    hash = "sha256-qUMdLe8BYWC57Yl1KnRtrNlfGo5LuxfOAIt2jzvKXdA=";
  };
in
{
  nix-plugin-pijul = final.stdenv.mkDerivation {
    pname = "nix-plugin-pijul";
    version = "0.1.7";

    src = source;

    strictDeps = true;

    nativeBuildInputs = with final; [
      meson
      ninja
      pkg-config
      pijul
    ];

    buildInputs = with final; [
      boost
      howard-hinnant-date
      nix
      nlohmann_json
    ];

    mesonFlags = [
      "-Dpijul_path=${final.lib.getExe final.pijul}"
    ];

    passthru.nixPackage = final.nix;

    meta = {
      description = "Pijul input fetcher plugin for Nix";
      homepage = "https://office-desktop.tail5ca7.ts.net:7443/jrestivo/nix-plugin-pijul";
      license = final.lib.licenses.lgpl3Only;
      platforms = final.lib.platforms.unix;
    };
  };
}
