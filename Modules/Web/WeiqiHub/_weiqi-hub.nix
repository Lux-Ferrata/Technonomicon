{ pkgs }:

let
  version = "0.1.13";
  src = pkgs.fetchurl {
    url = "https://github.com/ale64bit/WeiqiHub/releases/download/v${version}/WeiqiHub-v${version}-x86_64.AppImage";
    hash = "sha256-+mOWf3XTPuvskJV+TBD368LHRzxesBDBldSI1QvTggE=";
  };
in
pkgs.appimageTools.wrapType2 {
  pname = "weiqi-hub";
  inherit version src;
}
