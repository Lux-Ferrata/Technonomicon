{ inputs, ... }: {
  flake.nixosModules.Tn-utf = { pkgs, ... }: {

    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "zh_CN.UTF-8/UTF-8"
        "ko_KR.UTF-8/UTF-8"
        "ja_JP.UTF-8/UTF-8"
      ];

      inputMethod = {
        type = "fcitx5";
        enable = true;
        fcitx5 = {
          waylandFrontend = true;
          addons = with pkgs; [
            fcitx5-gtk
            qt6Packages.fcitx5-chinese-addons   # pinyin
            qt6Packages.fcitx5-configtool
            fcitx5-nord
          ];
        };
      };
    };

    # English + Pinyin only. Super+Esc (Hyprland, `fcitx5-remote -t`) flips
    # between them. force: fcitx5 had written its own keyboard-only profile.
    home-manager.users.xin.xdg.configFile."fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        Name=Default
        Default Layout=us
        DefaultIM=pinyin

        [Groups/0/Items/0]
        Name=keyboard-us
        Layout=

        [Groups/0/Items/1]
        Name=pinyin
        Layout=

        [GroupOrder]
        0=Default
      '';
    };
  };
}
