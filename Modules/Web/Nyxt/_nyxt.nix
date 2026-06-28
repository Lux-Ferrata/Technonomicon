{ pkgs }:

let
  version = "4.0.0";
  archive = pkgs.fetchurl {
    url = "https://github.com/atlas-engineer/nyxt/releases/download/${version}/Linux-Nyxt-x86_64.tar.gz";
    sha256 = "0zc4pha3hmlaxwa3v9prd1jfiwdv2pblclfjjmk5ks16vx9df3ma";
  };
  appimage = pkgs.runCommand "nyxt-${version}.AppImage" { } ''
    tar -xf ${archive}
    mv Nyxt-x86_64.AppImage $out
  '';
in
pkgs.appimageTools.wrapType2 {
  pname = "nyxt";
  inherit version;
  src = appimage;
}
