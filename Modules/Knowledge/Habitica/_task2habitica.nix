{ pkgs }:

let
  version = "0.3.1";
  src = pkgs.fetchFromGitHub {
    owner = "mainframev";
    repo = "task2habitica-rs";
    rev = "75d63b95a52dacb2287653375efa6113aff71c2a";
    hash = "sha256-amnCaE/d/pExOHkS8okkTB0WAEXUcxOyQ/F6Gx1AcgY=";
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "task2habitica";
  inherit version src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.openssl ];

  meta = with pkgs.lib; {
    description = "Bidirectional sync tool between Taskwarrior and Habitica";
    homepage = "https://github.com/mainframev/task2habitica-rs";
    license = licenses.mit;
    mainProgram = "task2habitica";
    platforms = platforms.unix;
  };
}
