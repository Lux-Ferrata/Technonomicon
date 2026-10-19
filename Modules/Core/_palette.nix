# Technonomicon's colours: Nord's hues, saturated, on a dark grey ground.
# The one palette for the desktop (the base16 scheme "tn", Tn-theme),
# VSCodium (Tn-neovim) and both nvims (_tn-nvim.lua). Previewed and approved
# 2026-10-10.
#
# How it was made, and how to change a colour without breaking it:
# - The ground is a dark grey, #252728 (was Dark Reader's near-black
#   #181A1B until 2026-10-17; every dark tone moved up by the same OKLab
#   lightness, +.055). Text is Dark Reader's #E8E6E3. Dark Reader takes
#   both from its settings in sops (dark-reader-settings, Tn-web-browsers),
#   imported by hand, so web pages and the desktop match; change them with
#   base00/base05.
# - Each accent keeps its Nord hue, takes about 1.8x Nord's OKLCH chroma,
#   and gets the lowest lightness that reaches its contrast target on the
#   ground: comments ~9.5:1, strings ~8, teal ~9, constants, definitions
#   and warnings ~6.5, errors 4.5. A true red can't go much past 5:1 on a
#   dark ground without turning pink.
# - Any two coloured roles stay >= 0.12 apart in OKLab (yellow/green is the
#   closest pair at 0.126), so none can be mistaken for another.
# Highlighting follows Tonsky ("I am sorry, but everyone is getting syntax
# highlighting wrong") and his Alabaster Dark: comments yellow, strings
# green, constants red, definitions blue, punctuation grey, keywords
# and everything else plain, no bold or italic. One departure, xin's:
# operators (- = + ...) are yellow like comments.
rec {
  # Contrast on base00, then OKLCH (L C h).
  base16 = {
    base00 = "252728";  # ground, dark grey                   .271 .004 229
    base01 = "2C3136";  # surfaces: popups, status bars, bar  .309 .011 254
    base02 = "374657";  # selection, hover; text on it 7.7:1  .390 .035 251
    base03 = "848E99";  # dim: line numbers, inactive   4.5   .641 .020 251
    base04 = "B8BEC5";  # secondary text                8.0   .798 .012 252
    base05 = "E8E6E3";  # text (Dark Reader)           12.0   .925 .005  78
    base06 = "F0EFEC";  #                              13.0
    base07 = "FBFAF8";  # brightest                    14.4
    base08 = "FC4F4B";  # red: constants, errors, dels  4.5   .669 .210  26  Nord11
    base09 = "FF8D3E";  # orange: warnings, search      6.5   .755 .164  52  Nord12
    base0A = "EDCB6C";  # yellow: comments              9.5   .851 .121  90  Nord13
    base0B = "8BCF74";  # green: strings, additions     8.1   .787 .140 138  Nord14
    base0C = "5EDBE2";  # teal: info, terminal cyan     9.1   .823 .110 200  Nord7/8
    base0D = "6EB0F4";  # blue: definitions, UI accent  6.6   .740 .120 251  Nord9
    base0E = "D893DA";  # purple: terminal magenta      6.5   .754 .125 326  Nord15
    base0F = "4A89DB";  # deep blue                     4.2   .626 .141 256  Nord10
  };

  # What every app uses. Pick colours by role, never by slot or hex.
  roles = let s = n: "#${base16.${n}}"; in {
    bg         = s "base00";
    surface    = s "base01";
    sel        = s "base02";   # text selection and hover
    dim        = s "base03";
    second     = s "base04";
    plain      = s "base05";
    bright     = s "base07";
    linehl     = "#2A2C2F";    # current-line band          .293 .006 258
    border     = "#3F444A";    # borders, separators   1.4  .385 .012 250
    whitespace = "#4A4F55";    # whitespace dots, guides 1.7 .425 .012 250
    punct      = "#9CAEB8";    # punctuation            6.5  .739 .025 234
    ghost      = "#687983";    # inline suggestions    3.3  .565 .025 234
    comment    = s "base0A";
    operator   = s "base0A";   # - = + etc. like comments, as xin asked
    string     = s "base0B";
    const      = s "base08";   # red, as xin asked (was purple)
    def        = s "base0D";
    accent     = s "base0D";   # focus, active border, the row being chosen
    search     = s "base09";
    error      = s "base08";
    warn       = s "base09";
    info       = s "base0C";
    hint       = s "base0B";
    add        = s "base0B";
    change     = s "base0D";
    del        = s "base08";
  };

  # Both as Lua tables (B, P) for _tn-nvim.lua.
  lua = let
    table = name: attrs: "local ${name} = { "
      + builtins.concatStringsSep ", "
          (map (k: "${k} = \"${attrs.${k}}\"") (builtins.attrNames attrs))
      + " }\n";
  in table "B" (builtins.mapAttrs (_: v: "#${v}") base16) + table "P" roles;
}
