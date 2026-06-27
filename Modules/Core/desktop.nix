{ inputs, ... }: {
  flake.nixosModules.Tn-desktop = { pkgs, pkgs-stable, config, ... }: {

    hardware = {
      bluetooth.enable = true;
      graphics.enable = true;
      xpadneo.enable = true;
      sane.enable = true;
      sane.extraBackends = [ pkgs.sane-airscan ];
    };

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
        package = pkgs.kanata-with-cmd;
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
      gnome.gnome-keyring.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        pulse.enable = true;
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

    fonts.packages = with pkgs; [
      iosevka
      iosevka-comfy.comfy-wide-motion
      iosevka-comfy.comfy-wide-motion-duo
      nerd-fonts.symbols-only
      nerd-fonts.jetbrains-mono
      jetbrains-mono
      sarasa-gothic
      noto-fonts
      overpass
      fira-code
      fira-go
    ];

    xdg.mime.defaultApplications = {
      "application/pdf" = "sioyek.desktop";
      "text/html" = "brave-browser.desktop";
      "application/xhtml+xml" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "x-scheme-handler/mailto" = "brave-browser.desktop";
    };

    services.udev.extraRules = ''
      KERNEL=="ttyACM[0-9]*", MODE="0666"
      KERNEL=="ttyUSB[0-9]*", MODE="0666"
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    security.sudo.extraConfig = "Defaults pwfeedback\n";
    security.pam.services.greetd.enableGnomeKeyring = true;

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
      wl-clipboard
      brightnessctl
      gnome-themes-extra
      adwaita-icon-theme
      kdePackages.skanlite

      inputs.plover-flake.packages.${pkgs.stdenv.hostPlatform.system}.plover-full
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
        };
        "org/virt-manager/virt-manager/connections" = {
          autoconnect = [ "qemu:///system" ];
          uris = [ "qemu:///system" ];
        };
      };

      gtk = {
        enable = true;
        theme.name = "Adwaita-dark";
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

      xdg.userDirs = {
        enable = true;
        createDirectories = false;
        setSessionVariables = true;
        desktop     = "$HOME/Archive";
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

    services.logind.settings.Login.HandleSuspend = "ignore";

  };
}
