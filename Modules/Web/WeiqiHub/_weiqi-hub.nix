{ pkgs }:

let
  version = "0.1.13";
  src = pkgs.fetchurl {
    url = "https://github.com/ale64bit/WeiqiHub/releases/download/v${version}/WeiqiHub-v${version}-x86_64.AppImage";
    hash = "sha256-+mOWf3XTPuvskJV+TBD368LHRzxesBDBldSI1QvTggE=";
  };
in
let
  appimage = pkgs.appimageTools.wrapType2 {
    pname = "weiqi-hub";
    inherit version src;
  };
  extracted = pkgs.appimageTools.extractType2 { pname = "weiqi-hub"; inherit version src; };
in
pkgs.symlinkJoin {
  name = "weiqi-hub-${version}";
  paths = [ appimage ];
  postBuild = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
    sed 's|^Exec=wqhub|Exec=weiqi-hub|' ${extracted}/com.walruswq.wqhub.desktop \
      > $out/share/applications/com.walruswq.wqhub.desktop
    cp ${extracted}/wqhub.png $out/share/icons/hicolor/256x256/apps/wqhub.png
  '';
}
