{ inputs, ... }: {
  flake.nixosModules.Tn-desktop = { pkgs, pkgs-stable, config, ... }:
    let
      ploverPkg = inputs.plover-flake.packages.${pkgs.stdenv.hostPlatform.system}.plover-full;
      ploverOpen = pkgs.writeShellScriptBin "plover-open" ''
        pkill -f '\.plover-wrapped' 2>/dev/null || true
        sleep 0.5
        exec env QT_QPA_PLATFORM=xcb ${ploverPkg}/bin/plover
      '';
    in {

    hardware = {
      bluetooth.enable = true;
      graphics.enable = true;
      xpadneo.enable = true;
    };

    security.rtkit.enable = true;

    # needs the xdg portal below, so it lives with the desktop
    services.flatpak.enable = true;

    services = {
      greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
            user = "greeter";
          };
        };
      };

      kanata = {
        enable = true;
        # plain kanata: the layout runs no shell commands
        keyboards.colmacs.configFile = ./_kanata.kbd;
      };

      libinput = {
        enable = true;
        touchpad = {
          tappingDragLock = false;
          middleEmulation = false;
        };
      };
      upower.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        pulse.enable = true;
        jack.enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
      };
    };

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    # Atkinson Hyperlegible everywhere: Next for text and UI (there is no
    # serif, so it stands in for serif too), Mono with ligatures and Nerd
    # Font icons for code (_atkinson-mono-liga.nix). The rest is coverage:
    # CJK (Sarasa), emoji, math symbols, icons Atkinson lacks.
    fonts.packages = with pkgs; [
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono
      (callPackage ./_atkinson-mono-liga.nix { })
      nerd-fonts.symbols-only
      sarasa-gothic
      noto-fonts
      noto-fonts-color-emoji
      julia-mono
      cm_unicode
    ];

    fonts.fontconfig.defaultFonts = {
      serif      = [ config.tn.ui_font "Noto Serif" ];
      sansSerif  = [ config.tn.ui_font "Noto Sans" ];
      monospace  = [ config.tn.primary_font "Noto Sans Mono" ];
    };

    xdg.mime.defaultApplications = {
      "application/pdf"          = "sioyek.desktop";
      "text/plain"               = "nvim.desktop";
      "text/markdown"            = "nvim.desktop";
      "text/x-markdown"          = "nvim.desktop";
      "text/html"                = "brave-browser.desktop";
      "application/xhtml+xml"    = "brave-browser.desktop";
      "x-scheme-handler/http"    = "brave-browser.desktop";
      "x-scheme-handler/https"   = "brave-browser.desktop";
      "x-scheme-handler/about"   = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "x-scheme-handler/mailto"  = "brave-browser.desktop";

      # Without these, whatever app last claimed the type won: folders opened
      # in VSCodium, images in Brave, and zips in zathura's comic-book viewer.
      "inode/directory"              = "nemo.desktop";
      "image/png"                    = "imv.desktop";
      "image/jpeg"                   = "imv.desktop";
      "image/gif"                    = "imv.desktop";
      "image/webp"                   = "imv.desktop";
      "image/bmp"                    = "imv.desktop";
      "image/tiff"                   = "imv.desktop";
      "application/zip"              = "org.gnome.FileRoller.desktop";
      "application/x-tar"            = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed"  = "org.gnome.FileRoller.desktop";
      "application/vnd.rar"          = "org.gnome.FileRoller.desktop";
    };

    # Qt apps (sioyek, Anki, Krita, OBS…) in the same Adwaita-dark as GTK.
    qt = {
      enable = true;
      style  = "adwaita-dark";
    };

    # Serial devices (steno machines, boards) stay root:dialout 0660; xin is
    # in dialout, so they needn't be open to everyone.
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    security.sudo.extraConfig = "Defaults pwfeedback\n";

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "0";
      QT_SCALE_FACTOR = "1";
      GDK_SCALE = "1";
      GDK_BACKEND = "wayland,x11";
      ANKI_WAYLAND = "1";
      NIXPKGS_ALLOW_UNFREE = "1";
    };

    environment.systemPackages = with pkgs; [
      grim
      slurp
      wtype
      blueman
      gromit-mpx
      pavucontrol
      file-roller
      wl-clipboard
      brightnessctl
      gnome-themes-extra
      adwaita-icon-theme

      gparted
      udiskie
      nemo-with-extensions
      antigravity-ide-fhs
      mpv

      ploverPkg
      ploverOpen
      (makeDesktopItem {
        name        = "plover-open";
        desktopName = "Plover";
        exec        = "${ploverOpen}/bin/plover-open";
        icon        = "plover";
        terminal    = false;
        categories  = [ "Utility" ];
      })
    ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
      github-desktop
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ pkgs.xdg-desktop-portal-gtk ];
    };

    programs.steam.enable = true;
    programs.ydotool.enable = true;

    programs.appimage = {
      enable = true;
      binfmt = true;
      package = pkgs.appimage-run.override {
        extraPkgs = pkgs: with pkgs; [
          libepoxy
          brotli
          xdg-user-dirs
        ];
      };
    };

    programs.dconf.enable = true;

    home-manager.users.xin = {
      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita-dark";
          font-name           = "${config.tn.ui_font} 11";
          document-font-name  = "${config.tn.ui_font} 11";
          monospace-font-name = "${config.tn.primary_font} 11";
        };
        "org/nemo/preferences" = {
          show-hidden-files = false;
        };
        # GTK/portal file pickers (Brave etc.) — Ctrl+H toggles, rebuild resets
        "org/gtk/settings/file-chooser" = {
          show-hidden = false;
        };
        "org/gtk/gtk4/settings/file-chooser" = {
          show-hidden = false;
        };
        # virt-manager's connections are set in Tn-virtualization
      };

      gtk = {
        enable = true;
        theme.name = "Adwaita-dark";
        font = { name = config.tn.ui_font; size = 11; };
        iconTheme = {
          package = pkgs.adwaita-icon-theme;
          name    = "Adwaita";
        };
        gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
        gtk4 = {
          theme.name = "Adwaita-dark";
          extraConfig.gtk-application-prefer-dark-theme = 1;
        };
      };

      home.file.".local/share/applications/plover.desktop".text = ''
        [Desktop Entry]
        Name=Plover
        NoDisplay=true
        Type=Application
      '';

      xdg.userDirs = {
        enable = true;
        createDirectories = false;
        setSessionVariables = true;
        desktop     = "$HOME/Media";
        download    = "$HOME/Downloads";
        templates   = "$HOME/Projects";
        publicShare = "$HOME/Projects";
        documents   = "$HOME/Media";
        music       = "$HOME/Media";
        pictures    = "$HOME/Media";
        videos      = "$HOME/Media";
      };

      home.file = {
        ".config/fcitx5/config".source = ./_fcitx5-config;
        ".config/gromit-mpx.cfg".source = ./_gromit-mpx.cfg;
        ".config/gromit-mpx.ini".source = ./_gromit-mpx.ini;
      };
    };

  };
}
