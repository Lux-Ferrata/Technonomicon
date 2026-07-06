{ pkgs }:

pkgs.appimageTools.wrapType2 {
  pname = "pomodorolm";
  version = "0.9.1";
  src = pkgs.fetchurl {
    url = "https://github.com/vjousse/pomodorolm/releases/download/app-v0.9.1/pomodorolm_0.9.1_amd64.AppImage";
    hash = "sha256-kZYJnmFZFHVgX4IBWg6cyjuHeQWtUkLLnxyaeWIHZAQ=";
  };
}
