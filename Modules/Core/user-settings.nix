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
      primary_font = lib.mkOption {
        type    = lib.types.str;
        default = "Iosevka";
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
