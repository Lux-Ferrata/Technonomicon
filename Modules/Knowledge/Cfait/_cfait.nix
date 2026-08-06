{ pkgs }:

let
  version = "1.1.3";
  src = pkgs.fetchFromGitHub {
    owner = "trougnouf";
    repo = "cfait";
    rev = "v${version}";
    hash = "sha256-bWpxmx5/l3lR+Zy+9+1QaiCHtFlYXFdsb7G8DOIAp44=";
  };
in
pkgs.rustPlatform.buildRustPackage {
  pname = "cfait";
  inherit version src;

  # Default features = ["tui"]; the gui/mobile bins need their own features,
  # so a plain build yields only the `cfait` TUI binary.
  cargoHash = "sha256-QTOnTsxt4/2CKEaDwCalkcR0/8IfslhZtpSAK82Lw04=";

  meta = with pkgs.lib; {
    description = "Powerful, fast and elegant task/TODO manager (TUI) with CalDAV sync";
    homepage = "https://github.com/trougnouf/cfait";
    license = licenses.gpl3Plus;
    mainProgram = "cfait";
    platforms = platforms.unix;
  };
}
