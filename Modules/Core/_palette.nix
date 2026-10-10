# Technonomicon's colours: Nord's hues, saturated, on Dark Reader's ground.
# The one palette for the desktop (the base16 scheme "tn", Tn-theme),
# VSCodium (Tn-neovim) and both nvims (_tn-nvim.lua). Previewed and approved
# 2026-10-10.
#
# How it was made, and how to change a colour without breaking it:
# - The ground and text are Dark Reader's defaults (#181A1B, #E8E6E3), so
#   web pages and the desktop match.
# - Each accent keeps its Nord hue, takes about 1.8x Nord's OKLCH chroma,
#   and gets the lowest lightness that reaches its contrast target on the
#   ground: comments ~11:1, strings ~9, constants and definitions ~7,
#   errors 5. A true red can't pass 7:1 on a dark ground without turning
#   pink, so red stops at 5.
# - Any two coloured roles stay >= 0.12 apart in OKLab (yellow/green is the
#   closest pair at 0.130), so none can be mistaken for another.
# Highlighting follows Tonsky ("I am sorry, but everyone is getting syntax
# highlighting wrong") and his Alabaster Dark: comments yellow, strings
# green, constants red, definitions blue, punctuation grey, keywords
# and everything else plain, no bold or italic.
rec {
  # Contrast on base00, then OKLCH (L C h).
  base16 = {
    base00 = "181A1B";  # ground (Dark Reader)                .216 .004 229
    base01 = "1F2328";  # surfaces: popups, status bars, bar  .254 .011 254
    base02 = "293848";  # selection, hover; text on it 9.6:1  .335 .035 251
    base03 = "7B8590";  # dim: line numbers, inactive   4.7   .612 .020 251
    base04 = "B5BBC2";  # secondary text                9.0   .789 .012 252
    base05 = "E8E6E3";  # text (Dark Reader)           14.0   .926 .005  78
    base06 = "F1F0ED";  #                              15.3
    base07 = "FBFAF8";  # brightest                    16.7
    base08 = "F74A47";  # red: constants, errors, dels  5.0   .656 .210  26  Nord11
    base09 = "FA852F";  # orange: warnings, search      7.0   .734 .170  52  Nord12
    base0A = "ECCA6B";  # yellow: comments             11.0   .849 .121  90  Nord13
    base0B = "88CB71";  # green: strings, additions     9.0   .776 .140 138  Nord14
    base0C = "53D1D8";  # teal: info, terminal cyan     9.5   .794 .110 200  Nord7/8
    base0D = "69ABEF";  # blue: definitions, UI accent  7.2   .725 .120 251  Nord9
    base0E = "D28DD4";  # purple: terminal magenta      7.1   .736 .125 326  Nord15
    base0F = "4684D6";  # deep blue                     4.6   .611 .141 256  Nord10
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
    linehl     = "#1D1F22";    # current-line band          .238 .006 258
    border     = "#31363B";    # borders, separators   1.4  .330 .012 250
    whitespace = "#3B4046";    # whitespace dots, guides 1.7 .370 .012 250
    punct      = "#81929C";    # punctuation, operators 5.4  .650 .025 234
    comment    = s "base0A";
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
