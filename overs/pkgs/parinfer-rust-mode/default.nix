{ stdenv, rustPlatform, fetchFromGitHub, llvmPackages }:

rustPlatform.buildRustPackage rec {
  pname = "parinfer-rust-mode-overlay";
  version = "0.4.3";

  src = fetchFromGitHub {
    owner = "eraserhd";
    repo = "parinfer-rust";
    rev = "v${version}";
    sha256 = "0hj5in5h7pj72m4ag80ing513fh65q8xlsf341qzm3vmxm3y3jgd";
  };

  cargoSha256 = "175lgplg47fxwdlyi0abh4xpz65yakg1kmmh1jjbmb7mj3qsr77c";


  nativeBuildInputs = [ llvmPackages.clang ];
  buildInputs = [ llvmPackages.libclang ];
  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";

  meta = with stdenv.lib; {
    description = "Infer parentheses for Clojure, Lisp, and Scheme.";
    homepage = "https://github.com/eraserhd/parinfer-rust";
    license = licenses.isc;
    maintainers = with maintainers; [ eraserhd ];
    platforms = platforms.all;
  };
}
