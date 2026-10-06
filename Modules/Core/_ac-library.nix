# nixpkgs' `ac-library` installs only bin/expander -- it ships none of the
# atcoder/*.hpp headers, so it cannot actually be #included. This packages
# the headers themselves; `expander` from nixpkgs still inlines them into a
# single file for submission. Shared by Tn-devtools and Tn-neovim (clangd).
{ stdenvNoCC, fetchFromGitHub }:
stdenvNoCC.mkDerivation {
  pname   = "ac-library-headers";
  version = "1.6";
  src = fetchFromGitHub {
    owner  = "atcoder";
    repo   = "ac-library";
    rev    = "v1.6";
    hash   = "sha256-zV2G9Ur2v8elGVKuO9w7ampaB13wDod9qzo7+QXq6G4=";
  };
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/include
    cp -r atcoder $out/include/
  '';
  meta.description = "Official AtCoder Library, headers only";
}
