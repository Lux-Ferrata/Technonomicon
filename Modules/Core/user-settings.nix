{ ... }: {
  flake.nixosModules.Tn-user-settings = { lib, ... }: {
    options.tn = {
      full_name = lib.mkOption {
        type    = lib.types.str;
        default = "";
      };
      email_address = lib.mkOption {
        type    = lib.types.str;
        default = "";
      };
      theme = lib.mkOption {
        type    = lib.types.str;
        default = "nord";
      };
      wallpaper_path = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
      };
      # monospace: terminals, editors, bar, launchers (Tn-desktop installs it)
      primary_font = lib.mkOption {
        type    = lib.types.str;
        default = "Atkinson Hyperlegible Mono Liga";
      };
      # proportional: GTK/Qt and the fontconfig sans/serif defaults
      ui_font = lib.mkOption {
        type    = lib.types.str;
        default = "Atkinson Hyperlegible Next";
      };
      scale = lib.mkOption {
        type    = lib.types.int;
        default = 1;
      };
      quick_app_bindings = lib.mkOption {
        type    = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Map of key suffix (e.g. \"A\") to command (e.g. \"brave --app=...\") for SUPER+key bindings.";
      };
    };
  };
}
