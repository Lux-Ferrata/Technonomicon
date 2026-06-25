{ inputs, ... }: {
  # Surfingkeys config
  home.file.".config/surfingkeys/config.js".source =
    "${inputs.self}/Modules/Web/_surfingkeys.js";

  # Discord: skip host update check
  home.file.".config/discord/settings.json".text = builtins.toJSON {
    SKIP_HOST_UPDATE = true;
  };

  # Ghostty terminal config
  home.file.".config/ghostty/config".text = ''
    font-family = Iosevka
    font-size = 13

    theme = custom-dark

    cursor-style = block
    cursor-style-blink = false

    shell-integration-features = no-cursor

    window-padding-x = 8
    window-padding-y = 6

    background-opacity = 0.97
    background-blur-radius = 20
  '';

  home.file.".config/ghostty/themes/custom-dark".text = ''
    background = 1D232F
    foreground = CFDFDF

    cursor-color = 00FFFF

    selection-background = 2E3A4E
    selection-foreground = CFDFDF

    palette = 0=#1D232F
    palette = 1=#FF5370
    palette = 2=#4CAF50
    palette = 3=#FFCB6B
    palette = 4=#539BF5
    palette = 5=#C792EA
    palette = 6=#00FFFF
    palette = 7=#CFDFDF
    palette = 8=#3D4F63
    palette = 9=#FF7070
    palette = 10=#69D98C
    palette = 11=#FFD880
    palette = 12=#7DBFFF
    palette = 13=#D9AAFF
    palette = 14=#4DFFFF
    palette = 15=#E8F0F0
  '';

  # Mako notification daemon
  services.mako = {
    enable = true;
    settings.default-timeout = 3000;
  };
}
