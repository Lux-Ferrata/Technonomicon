{ inputs, ... }: {
  flake.nixosModules.Tn-hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable   = true;
      withUWSM = true;
    };

    security.pam.services.hyprlock = {};

    environment.systemPackages = with pkgs; [
      hyprlandPlugins.hypr-dynamic-cursors
      hyprlock
      hypridle
      hyprpaper
      waybar
      anyrun
      wl-kbptr
      grim
      slurp
      wl-clipboard
      wtype
      hyprpicker
      satty
      wf-recorder
      awww
      wlogout
      nwg-look
      hyprshot
    ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      NIXPKGS_ALLOW_UNFREE = "1";
    };
  };
}
