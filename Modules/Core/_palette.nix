# Technonomicon high contrast: the one palette for the desktop (as the
# base16 scheme "tn-contrast", Tn-theme), VSCodium and nvim (Tn-neovim,
# Tn-server-nvim). Pure black ground, pure white text, and accents only in
# blue, green, dark orange and red, each >= 7:1 on the black and on the
# panel shade base01 (WCAG AAA); the numbers are each colour on #000000.
rec {
  base16 = {
    base00 = "000000";  # background
    base01 = "101318";  # panels, floats, status lines
    base02 = "22324A";  # selection
    base03 = "A3ABBA";  # dim text: line numbers, inactive   9.1:1
    base04 = "D3D8E0";  # secondary text                    14.7:1
    base05 = "FFFFFF";  # text                              21:1
    base06 = "FFFFFF";
    base07 = "FFFFFF";
    base08 = "FF7373";  # red                                8.0:1
    base09 = "FF8A1F";  # dark orange                        8.9:1
    base0A = "FFB224";  # amber (warnings)                  11.6:1
    base0B = "4BE37A";  # green                             12.6:1
    base0C = "5CCBFF";  # light blue                        11.4:1
    base0D = "7AB0FF";  # blue                               9.5:1
    base0E = "FF7A9E";  # rose red                           8.5:1
    base0F = "FF7B52";  # red-orange                         8.2:1
  };

  # Alabaster-style syntax: only what reading needs is coloured
  syntax = {
    bg      = "#${base16.base00}";
    panel   = "#${base16.base01}";
    sel     = "#${base16.base02}";
    dim     = "#${base16.base03}";
    plain   = "#${base16.base05}";  # keywords, calls, variables, punctuation
    comment = "#${base16.base09}";  # comments matter: dark orange
    string  = "#${base16.base0B}";  # green
    const   = "#${base16.base08}";  # numbers, booleans, constants: red
    def     = "#${base16.base0D}";  # definitions: blue
    info    = "#${base16.base0C}";
    warn    = "#${base16.base0A}";
  };

  # the same, as a Lua table for _tn-contrast.lua
  lua = "local P = { "
    + builtins.concatStringsSep ", "
        (map (k: "${k} = \"${syntax.${k}}\"") (builtins.attrNames syntax))
    + " }\n";
}
