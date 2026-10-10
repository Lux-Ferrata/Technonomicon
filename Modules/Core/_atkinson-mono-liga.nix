# Atkinson Hyperlegible Mono with programming ligatures, as the family
# "Atkinson Hyperlegible Mono Liga". Atkinson ships none (no calt/liga), and
# ligatures can't come from a fallback font (fallback only covers missing
# characters; -> and != are plain ASCII the font already has), so
# Ligaturizer copies Fira Code's ligature glyphs into it at build time.
# The base is the Nerd Font Mono build (AtkynsonMono NFM), so terminal and
# bar icons come along. Only the four styles editors and terminals ask for
# (Regular, Bold, Italic, Bold Italic): renaming Light/Medium the same way
# would leave them claiming to be "Regular".
{ stdenvNoCC, fetchFromGitHub, fontforge, nerd-fonts }:
let
  ligaturizer = fetchFromGitHub {
    name  = "ligaturizer-src";
    owner = "ToxicFrog";
    repo  = "Ligaturizer";
    rev   = "c4065187a544a8fab40826fc91db1c6180a2d342";
    hash  = "sha256-89/6xEBybIG9OfeOkwh8bwvQpp8+SOCbUxIlqbdkvqU=";
  };
  # the Fira Code commit Ligaturizer's submodule pins (its glyph names)
  fira = fetchFromGitHub {
    name  = "firacode-otf-src";
    owner = "tonsky";
    repo  = "FiraCode";
    rev   = "e9943d2d631a4558613d7a77c58ed1d3cb790992";
    sparseCheckout = [ "distr/otf" ];
    hash  = "sha256-UUrN2HY4v0ME6Bz8IvBt/ftxrn+GfTb2mhcr1rrtMak=";
  };
  base = "${nerd-fonts.atkynson-mono}/share/fonts/opentype/NerdFonts/AtkynsonMono";
in
stdenvNoCC.mkDerivation {
  pname   = "atkinson-hyperlegible-mono-liga";
  version = nerd-fonts.atkynson-mono.version;
  src     = ligaturizer;

  nativeBuildInputs = [ fontforge ];

  buildPhase = ''
    runHook preBuild
    mkdir -p fonts/fira out
    cp -r ${fira}/distr fonts/fira/
    for style in Regular Bold Italic BoldItalic; do
      fontforge -lang=py -script ligaturize.py \
        ${base}/AtkynsonMonoNerdFontMono-$style.otf \
        --output-dir=out --prefix="" \
        --output-name="Atkinson Hyperlegible Mono Liga"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 -t $out/share/fonts/opentype out/*.otf
    runHook postInstall
  '';
}
