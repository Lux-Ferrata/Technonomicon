{ pkgs }:

let
  version = "1.0.0-rc.10";
  src = pkgs.fetchurl {
    url = "https://github.com/allusion-app/Allusion/releases/download/v${version}/Allusion-${version}.AppImage";
    hash = "sha256-5bBQjjb2vs3+s1r7+GOSVQbRBc8eyWjQFAlI3/mUh/k=";
  };
in
pkgs.appimageTools.wrapType2 {
  pname = "allusion";
  inherit version src;
}
