{ inputs, ... }: {
  flake.nixosModules.Tn-hyprland = { pkgs, config, lib, ... }:
  let
    nixosCfg = config;

    hyprlandPkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    activateObsidianHere = pkgs.writeShellScript "activate-obsidian-here" ''
      ${hyprlandPkg}/bin/hyprctl dispatch movetoworkspace current,class:^(obsidian)$
      ${hyprlandPkg}/bin/hyprctl dispatch focuswindow class:^(obsidian)$
    '';

    activateObsidian = pkgs.writeShellScript "activate-obsidian" ''
      ITEMS=$(${pkgs.glib}/bin/gdbus call --session \
        --dest org.kde.StatusNotifierWatcher \
        --object-path /StatusNotifierWatcher \
        --method org.freedesktop.DBus.Properties.Get \
        "org.kde.StatusNotifierWatcher" "RegisteredStatusNotifierItems" 2>/dev/null \
        | grep -oP "'\K[^']+")

      for ITEM in $ITEMS; do
        DEST="''${ITEM%%/*}"
        OBJ="/''${ITEM#*/}"

        TOOLTIP=$(${pkgs.glib}/bin/gdbus call --session \
          --dest "$DEST" --object-path "$OBJ" \
          --method org.freedesktop.DBus.Properties.Get \
          "org.kde.StatusNotifierItem" "ToolTip" 2>/dev/null)

        if echo "$TOOLTIP" | grep -q "Obsidian"; then
          ${pkgs.glib}/bin/gdbus call --session \
            --dest "$DEST" --object-path "$OBJ" \
            --method org.kde.StatusNotifierItem.Activate 0 0
          exit 0
        fi
      done
    '';

    wlKbptr = pkgs.wl-kbptr.overrideAttrs (oldAttrs: {
      mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dopencv=enabled" ];
      buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.opencv ];
    });

    wlKbptrFloat = pkgs.writeShellScript "wl-kbptr-float" ''
      while true; do
        WS=$(${hyprlandPkg}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.id')
        WINS=$(${hyprlandPkg}/bin/hyprctl clients -j \
          | ${pkgs.jq}/bin/jq -r --argjson ws "$WS" \
            '.[] | select(.workspace.id == $ws and .mapped) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"')
        echo "$WINS" | ${wlKbptr}/bin/wl-kbptr -o modes=floating -o cancellation_status_code=1 || break
      done
    '';

    wlKbptrTile = pkgs.writeShellScript "wl-kbptr-tile" ''
      while ${wlKbptr}/bin/wl-kbptr -o modes=tile -o cancellation_status_code=1; do true; done
    '';

    vimEdit = pkgs.writeShellScript "vim-edit" ''
      ${pkgs.wtype}/bin/wtype -M ctrl -k a
      sleep 0.15
      ${pkgs.wtype}/bin/wtype -M ctrl -k c
      sleep 0.15

      export TMPFILE=$(mktemp /tmp/vim-edit-XXXXXX.md)
      ${pkgs.wl-clipboard}/bin/wl-paste > "$TMPFILE"

      ghostty --title=vim-edit -e bash -c \
        'nvim "$TMPFILE"; ${pkgs.wl-clipboard}/bin/wl-copy < "$TMPFILE"; rm -f "$TMPFILE"'
    '';

    wayscrollshot =
      (inputs.wayscrollshot.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ../../patches/wayscrollshot-max-preview-height.patch ];
      }));

    scrollshot = pkgs.writeShellScript "scrollshot" ''
      ${wayscrollshot}/bin/wayscrollshot --clipboard --max-preview-height 36
    '';

    tnShowKeybindings = pkgs.writeShellScript "tn-show-keybindings"
      (builtins.readFile ../../bin/tn-show-keybindings);

    cleanWin = ''
      def clean_title:
        gsub("^[a-z][a-z-]* \\| "; "") |
        gsub("^[^\\x00-\\x7F] "; "") |
        gsub("^/\\S+ \\| "; "");
      def clean_class:
        gsub("^([a-z0-9]+\\.)+"; "") |
        split("-") | .[0] |
        (.[0:1] | ascii_upcase) + .[1:];
    '';

    winPicker = pkgs.writeShellScript "tn-win-picker" ''
      CHOICE=$(${hyprlandPkg}/bin/hyprctl clients -j | \
        ${pkgs.jq}/bin/jq -r '
          ${cleanWin}
          map(select(.focusHistoryID != 0)) | sort_by(.focusHistoryID) |
          .[] | [(.title | clean_title), (.class | clean_class), (.workspace.id | tostring), .address] | @tsv' | \
        awk -F'\t' '{ printf "%-50s %-12s ws:%-2s  %s\n", $1, $2, $3, $4 }' | \
        ${pkgs.wofi}/bin/wofi --dmenu --no-sort -p "window")
      ADDR=$(echo "$CHOICE" | awk '{ print $NF }')
      ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({window='address:$ADDR'}))"
    '';

    winPickerWs = pkgs.writeShellScript "tn-win-picker-ws" ''
      WS_ID=$(${hyprlandPkg}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.id')
      CHOICE=$(${hyprlandPkg}/bin/hyprctl clients -j | \
        ${pkgs.jq}/bin/jq -r --argjson ws "$WS_ID" '
          ${cleanWin}
          map(select(.workspace.id == $ws and .focusHistoryID != 0)) | sort_by(.focusHistoryID) |
          .[] | [(.title | clean_title), (.class | clean_class), .address] | @tsv' | \
        awk -F'\t' '{ printf "%-50s %-12s  %s\n", $1, $2, $3 }' | \
        ${pkgs.wofi}/bin/wofi --dmenu --no-sort -p "workspace window")
      ADDR=$(echo "$CHOICE" | awk '{ print $NF }')
      ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({window='address:$ADDR'}))"
    '';

    layoutToggle = pkgs.writeShellScript "tn-layout-toggle" ''
      LAYOUT=$(${hyprlandPkg}/bin/hyprctl getoption general:layout -j | ${pkgs.jq}/bin/jq -r .str)
      if [ "$LAYOUT" = scrolling ]; then
        ${hyprlandPkg}/bin/hyprctl eval "hl.config({general = {layout = 'monocle'}})"
      else
        ${hyprlandPkg}/bin/hyprctl eval "hl.config({general = {layout = 'scrolling'}})"
      fi
    '';

    winPull = pkgs.writeShellScript "tn-win-pull" ''
      WS_ID=$(${hyprlandPkg}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.id')
      ACTIVE=$(${hyprlandPkg}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.address')

      CHOICE=$(${hyprlandPkg}/bin/hyprctl clients -j | \
        ${pkgs.jq}/bin/jq -r --argjson ws "$WS_ID" \
          '.[] | select(.workspace.id == $ws and .floating == false) |
           [.title, .class, .address] | @tsv' | \
        awk -F'\t' '{ printf "%-50s %-25s  %s\n", $1, $2, $3 }' | \
        ${pkgs.wofi}/bin/wofi --dmenu --no-sort -p "pull to follow")
      TARGET=$(echo "$CHOICE" | awk '{ print $NF }')
      [ -z "$TARGET" ] && exit 0

      ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({window='address:$TARGET'}))"
      for i in $(seq 1 25); do ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.window.move({direction='left'}))"; done

      ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({window='address:$ACTIVE'}))"
      for i in $(seq 1 25); do ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.window.move({direction='left'}))"; done
    '';

  in {

    programs.hyprland.enable = true;
    programs.hyprland.package = hyprlandPkg;
    programs.hyprlock.enable = true;

    environment.systemPackages = with pkgs; [
      wlKbptr
      wofi
      quickshell
      hypridle
      bibata-cursors
      networkmanagerapplet
      udiskie
      clipse
      wl-clip-persist
      hyprpicker
      hyprsunset
      libnotify
      satty
      wf-recorder
      nwg-look
    ];

    environment.etc."scripts/net-info.sh" = {
      mode = "0755";
      text = ''
        #!/usr/bin/env bash
        CONN=$(${pkgs.networkmanager}/bin/nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep ':connected:' | awk -F: '{print $4 " (" $2 ") on " $1}')
        [ -z "$CONN" ] && CONN="Not connected"
        IP=$(${pkgs.networkmanager}/bin/nmcli -t -f IP4.ADDRESS dev show | awk -F: '$2 != "" {print $2}' | head -1)
        [ -z "$IP" ] && IP="none"
        exec ${pkgs.libnotify}/bin/notify-send "Network" "$(printf '%s\nIP: %s' "$CONN" "$IP")"
      '';
    };

    home-manager.users.xin = { config, lib, ... }:
    let
      palette      = config.colorScheme.palette;
      hasWallpaper = nixosCfg.tn.wallpaper_path != null;
      wallpaperPath = if hasWallpaper then nixosCfg.tn.wallpaper_path else "";
    in {

      home.pointerCursor = {
        package    = pkgs.bibata-cursors;
        name       = "Bibata-Modern-Classic";
        size       = 24;
        gtk.enable = true;
        x11.enable = true;
      };

      home.sessionPath = [ "$HOME/.local/share/tn/bin" ];

      home.file.".local/share/tn/bin/tn-show-keybindings" = {
        source     = tnShowKeybindings;
        executable = true;
      };

      programs.wofi = {
        enable = true;
        settings = {
          width        = 600;
          height       = 350;
          location     = "center";
          show         = "drun";
          filter_rate  = 100;
          allow_markup = true;
          allow_images = true;
          image_size   = 64;
          insensitive  = true;
          no_actions   = true;
        };
        style = ''
          * {
            font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", monospace;
            font-size: 14px;
          }
          window {
            background-color: #${palette.base00};
            border: 1px solid #${palette.base03};
            border-radius: 4px;
          }
          #input {
            background-color: #${palette.base01};
            color: #${palette.base05};
            border: none;
            border-radius: 4px;
            padding: 8px 12px;
            margin: 8px;
          }
          #input:focus { outline: none; }
          #inner-box { margin: 0 8px 8px 8px; }
          #entry {
            padding: 6px 10px;
            border-radius: 4px;
          }
          #entry:selected {
            background-color: #${palette.base02};
            color: #${palette.base0D};
          }
          #text {
            color: #${palette.base05};
            font-size: 16px;
            font-weight: 600;
            padding-left: 8px;
          }
          #text:selected { color: #${palette.base0D}; }
        '';
      };

      programs.ghostty = {
        enable = true;
        settings = {
          font-family           = nixosCfg.tn.primary_font;
          font-size             = 12;
          "window-decoration"   = "none";
          theme                 = "tn";
          keybind               = "ctrl+k=reset";
          command               = "zellij";
          "confirm-close-surface" = false;
        };
      };

      home.file.".config/ghostty/themes/tn".text = ''
        background = #${palette.base00}
        foreground = #${palette.base05}
        selection-background = #${palette.base02}
        selection-foreground = #${palette.base00}
        cursor-color = #${palette.base05}
        palette = 0=#${palette.base00}
        palette = 1=#${palette.base08}
        palette = 2=#${palette.base0B}
        palette = 3=#${palette.base0A}
        palette = 4=#${palette.base0D}
        palette = 5=#${palette.base0E}
        palette = 6=#${palette.base0C}
        palette = 7=#${palette.base05}
        palette = 8=#${palette.base03}
        palette = 9=#${palette.base08}
        palette = 10=#${palette.base0B}
        palette = 11=#${palette.base0A}
        palette = 12=#${palette.base0D}
        palette = 13=#${palette.base0E}
        palette = 14=#${palette.base0C}
        palette = 15=#${palette.base07}
      '';

      home.file.".config/btop/btop.conf".text = ''
        color_theme = "tn"
        rounded_corners = True
        graph_symbol = braille
        vim_keys = True
        shown_boxes = cpu mem net proc
        update_ms = 2000
        proc_sorting = cpu lazy
        temp_scale = celsius
        draw_clock =
      '';

      home.file.".config/btop/themes/tn.theme".text = ''
        # TN btop theme — mapped from Nord base16 palette
        theme[main_bg]         = "#${palette.base00}"
        theme[main_fg]         = "#${palette.base05}"
        theme[title]           = "#${palette.base0D}"
        theme[hi_fg]           = "#${palette.base0C}"
        theme[selected_bg]     = "#${palette.base02}"
        theme[selected_fg]     = "#${palette.base0D}"
        theme[inactive_fg]     = "#${palette.base03}"
        theme[graph_text]      = "#${palette.base04}"
        theme[meter_bg]        = "#${palette.base01}"
        theme[proc_misc]       = "#${palette.base0A}"
        theme[cpu_box]         = "#${palette.base02}"
        theme[mem_box]         = "#${palette.base02}"
        theme[net_box]         = "#${palette.base02}"
        theme[proc_box]        = "#${palette.base02}"
        theme[div_line]        = "#${palette.base03}"
        theme[temp_start]      = "#${palette.base0B}"
        theme[temp_mid]        = "#${palette.base0A}"
        theme[temp_end]        = "#${palette.base08}"
        theme[cpu_start]       = "#${palette.base0D}"
        theme[cpu_mid]         = "#${palette.base0C}"
        theme[cpu_end]         = "#${palette.base0B}"
        theme[free_start]      = "#${palette.base0B}"
        theme[free_mid]        = "#${palette.base0C}"
        theme[free_end]        = "#${palette.base0D}"
        theme[cached_start]    = "#${palette.base0E}"
        theme[cached_mid]      = "#${palette.base0D}"
        theme[cached_end]      = "#${palette.base0C}"
        theme[available_start] = "#${palette.base0B}"
        theme[available_mid]   = "#${palette.base0C}"
        theme[available_end]   = "#${palette.base0D}"
        theme[used_start]      = "#${palette.base08}"
        theme[used_mid]        = "#${palette.base09}"
        theme[used_end]        = "#${palette.base0A}"
        theme[download_start]  = "#${palette.base0D}"
        theme[download_mid]    = "#${palette.base0C}"
        theme[download_end]    = "#${palette.base0B}"
        theme[upload_start]    = "#${palette.base0E}"
        theme[upload_mid]      = "#${palette.base0D}"
        theme[upload_end]      = "#${palette.base0C}"
        theme[process_start]   = "#${palette.base0D}"
        theme[process_mid]     = "#${palette.base0C}"
        theme[process_end]     = "#${palette.base0B}"
      '';

      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd         = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd  = "hyprctl dispatch dpms on";
          };
          listener = [
            {
              timeout    = 300;
              on-timeout = "loginctl lock-session";
            }
            {
              timeout    = 330;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume  = "hyprctl dispatch dpms on && brightnessctl -r";
            }
          ];
        };
      };

      services.hyprpaper = lib.mkIf hasWallpaper {
        enable = true;
        settings = {
          preload   = [ wallpaperPath ];
          wallpaper = [ ",${wallpaperPath}" ];
        };
      };

      home.file = {

        ".config/hypr/hyprland.lua".text = ''
          hl.monitor({
            output   = "",
            mode     = "preferred",
            position = "auto",
            scale    = "auto",
          })

          local terminal = "ghostty"
          local mainMod  = "SUPER"

          hl.env("XCURSOR_SIZE",       "24")
          hl.env("XCURSOR_THEME",      "Bibata-Modern-Classic")
          hl.env("HYPRCURSOR_SIZE",    "24")
          hl.env("SDL_VIDEODRIVER",    "wayland")
          hl.env("MOZ_ENABLE_WAYLAND", "1")
          hl.env("QT_STYLE_OVERRIDE",  "kvantum")
          hl.env("EDITOR",             "nvim")
          hl.env("GTK_THEME",          "Adwaita:dark")
          hl.env("GDK_SCALE",          "${toString nixosCfg.tn.scale}")

          hl.config({ ['xwayland.force_zero_scaling'] = true })

          hl.window_rule({
            name      = "discord-workspace",
            match     = { class = "com.discordapp.Discord" },
            workspace = 9,
          })

          hl.window_rule({
            name   = "portal-dialog-size",
            match  = { class = "xdg-desktop-portal-gtk" },
            float  = true,
            size   = "860 600",
            center = true,
          })

          hl.window_rule({
            name   = "grimoire-inbox-float",
            match  = { title = "grimoire-inbox" },
            float  = true,
            size   = "900 600",
            center = true,
          })

          hl.window_rule({
            name   = "technonomicon-float",
            match  = { title = "technonomicon" },
            float  = true,
            size   = "900 600",
            center = true,
          })

          hl.window_rule({
            name   = "vim-edit-float",
            match  = { title = "vim-edit" },
            float  = true,
            size   = "900 600",
            center = true,
          })

          hl.window_rule({
            name   = "taskwarrior-tui-float",
            match  = { title = "taskwarrior-tui" },
            float  = true,
            size   = "900 600",
            center = true,
          })

          hl.window_rule({
            name  = "pavucontrol-float",
            match = { class = "pavucontrol" },
            float = true,
          })

          hl.window_rule({
            name  = "blueberry-float",
            match = { class = "blueberry.py" },
            float = true,
          })

          hl.window_rule({
            name   = "clipse-float",
            match  = { class = "clipse" },
            float  = true,
            size   = "700 400",
            center = true,
          })

          hl.window_rule({
            name       = "steam-float",
            match      = { class = "steam" },
            float      = true,
          })

          hl.window_rule({
            name       = "retroarch-fullscreen",
            match      = { class = "com.libretro.RetroArch" },
            fullscreen = true,
          })

          hl.on("hyprland.start", function()
            hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE GDK_BACKEND")
            hl.exec_cmd("quickshell")
            hl.exec_cmd("udiskie --tray")
            hl.exec_cmd("blueman-applet")
            hl.exec_cmd("wl-clip-persist --clipboard regular")
            hl.exec_cmd("clipse -listen")
            hl.exec_cmd("hyprsunset")
            hl.exec_cmd("systemctl --user start hyprpolkitagent")
            hl.exec_cmd("obsidian")
            -- hl.exec_cmd("env QT_QPA_PLATFORM=xcb plover")
            hl.exec_cmd("[workspace 9 silent] flatpak run com.discordapp.Discord")
          end)

          hl.config({
            input = {
              kb_layout                 = "us",
              follow_mouse              = 0,
              float_switch_override_focus = 0,
              sensitivity               = 0,
              touchpad = {
                natural_scroll      = false,
                disable_while_typing = true,
                drag_lock           = false,
              },
            },
            general = {
              gaps_in     = 5,
              gaps_out    = 0,
              border_size = 2,
              col = {
                active_border   = "rgba(${palette.base0D}ee)",
                inactive_border = "rgba(${palette.base03}aa)",
              },
              layout = "monocle",
            },
            decoration = {
              rounding = 4,
              blur = {
                enabled = true,
                size    = 5,
                passes  = 2,
              },
              shadow = {
                enabled = false,
              },
            },
            animations = {
              enabled = true,
            },
            cursor = {
              inactive_timeout = 0.5,
            },
            misc = {
              disable_hyprland_logo    = true,
              disable_splash_rendering = true,
              background_color         = "rgb(${palette.base00})",
            },
            ecosystem = {
              no_update_news = true,
            },
          })

          hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd("wofi --show drun --sort-order=alphabetical"))
          hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(terminal))
          hl.bind(mainMod .. " + S",          hl.dsp.exec_cmd("brave"))
          hl.bind(mainMod .. " + D",          hl.dsp.window.close())
          hl.bind(mainMod .. " + Q",          hl.dsp.exec_cmd("hyprlock"))
          hl.bind(mainMod .. " + SHIFT + Q",  hl.dsp.exec_cmd("${pkgs.systemd}/bin/systemd-run --user --no-block --collect /etc/scripts/clean-power-off.sh"))
          hl.bind(mainMod .. " + SHIFT + E",  hl.dsp.exit())
          hl.bind(mainMod .. " + F",          hl.dsp.exec_cmd("ghostty -e yazi $HOME"))
          hl.bind(mainMod .. " + SHIFT + F",  hl.dsp.exec_cmd("nemo"))
          hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd("${activateObsidian}"))
          hl.bind(mainMod .. " + 0",          hl.dsp.exec_cmd("ghostty --title=grimoire-inbox -e nvim $HOME/Grimoire/Inbox.md"))
          hl.bind(mainMod .. " + SHIFT + 0",  hl.dsp.exec_cmd("ghostty --title=technonomicon -e nvim $HOME/Projects/Technonomicon/README.md"))
          hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd("${vimEdit}"))
          hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd("ghostty --title=taskwarrior-tui -e taskwarrior-tui"))
          hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd("qalculate-gtk"))
          hl.bind(mainMod .. " + H",          hl.dsp.exec_cmd("$HOME/.local/share/tn/bin/tn-show-keybindings"))
          hl.bind(mainMod .. " + V",           hl.dsp.exec_cmd("ghostty --class=clipse -e clipse"))
          hl.bind(mainMod .. " + semicolon",  hl.dsp.exec_cmd("hyprctl dispatch togglefloating"))
          hl.bind(mainMod .. " + Tab",        hl.dsp.exec_cmd("hyprctl dispatch workspace r-1"))
          hl.bind(mainMod .. " + comma",      hl.dsp.exec_cmd("hyprctl dispatch workspace r+1"))
          hl.bind(mainMod .. " + minus",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive -100 0"))
          hl.bind(mainMod .. " + equal",      hl.dsp.exec_cmd("hyprctl dispatch resizeactive 100 0"))
          hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -100"))
          hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 100"))
          hl.bind("CTRL + " .. mainMod .. " + V", hl.dsp.exec_cmd("ghostty --class=clipse -e clipse"))
          hl.bind(mainMod .. " + Print",      hl.dsp.exec_cmd("hyprpicker -a"))

          hl.bind(mainMod .. " + left",  hl.dsp.layout("cycleprev"))
          hl.bind(mainMod .. " + right", hl.dsp.layout("cyclenext"))

          hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.window.move({ direction = "left"  }))
          hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.window.move({ direction = "down"  }))
          hl.bind(mainMod .. " + SHIFT + K",     hl.dsp.window.move({ direction = "up"    }))
          hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.window.move({ direction = "right" }))
          hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left"  }))
          hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
          hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up"    }))
          hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down"  }))

          for i = 1, 9 do
            hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
            hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
          end

          hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
          hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
          hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
          hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
          hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 10%+"))
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))

          hl.bind("Print",           hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
          hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
          hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("${winPickerWs}"))
          hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("${winPicker}"))
          hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("${winPull}"))

          hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("${layoutToggle}"))

          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),             { mouse = true })
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(),           { mouse = true })
          hl.bind(mainMod .. " + mouse:274", hl.dsp.exec_cmd("${scrollshot}"), { mouse = true })

          ${lib.concatStringsSep "\n          " (lib.mapAttrsToList (key: cmd: ''hl.bind(mainMod .. " + ${key}", hl.dsp.exec_cmd("${cmd}"))''
          ) nixosCfg.tn.quick_app_bindings)}
        '';

        ".config/hypr/hyprlock.conf".text = ''
          general {
            disable_loading_bar = true
          }

          background {
            path        = "${wallpaperPath}"
            color       = rgba(${palette.base00}ff)
            blur_passes = 3
            blur_size   = 7
          }

          input-field {
            size             = 600, 100
            position         = 0, 0
            halign           = center
            valign           = center
            outer_color      = rgba(${palette.base01}ff)
            inner_color      = rgba(${palette.base01}ff)
            font_color       = rgba(${palette.base05}ff)
            check_color      = rgba(${palette.base0D}ff)
            fail_color       = rgba(${palette.base08}ff)
            font_family      = JetBrainsMono Nerd Font
            font_size        = 32
            placeholder_text = <span foreground="##${palette.base04}"> </span>
            dots_center      = true
            rounding         = 0
            fade_on_empty    = false
          }
        '';

        ".config/quickshell/shell.qml".text = ''
          import Quickshell

          ShellRoot {
              Variants {
                  model: Quickshell.screens
                  delegate: Bar {
                      required property var modelData
                      screen: modelData
                  }
              }

              Notifications {}
          }
        '';

        ".config/quickshell/Bar.qml".text = ''
          pragma ComponentBehavior: Bound
          import Quickshell
          import Quickshell.Io
          import Quickshell.Hyprland
          import Quickshell.Services.SystemTray
          import Quickshell.Services.Pipewire
          import Quickshell.Services.UPower
          import QtQuick
          import QtQuick.Layouts

          PanelWindow {
              id: root
              required property ShellScreen screen

              anchors { top: true; left: true; right: true }
              implicitHeight: 36
              color: "#eb${palette.base00}"

              PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
              Process { id: pavuProcess; command: ["${pkgs.pavucontrol}/bin/pavucontrol"] }

              Rectangle {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                  height: 1
                  color: "#4d${palette.base0C}"
              }

              RowLayout {
                  anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                  spacing: 4

                  Repeater {
                      model: Hyprland.workspaces
                      delegate: Item {
                          id: wsBtn
                          required property HyprlandWorkspace modelData
                          implicitWidth: 28
                          implicitHeight: 28

                          Rectangle {
                              anchors.centerIn: parent
                              width: 22; height: 22; radius: 4
                              color: wsBtn.modelData === Hyprland.focusedWorkspace
                                  ? "#${palette.base0D}" : "transparent"

                              Text {
                                  anchors.centerIn: parent
                                  text: wsBtn.modelData.id
                                  color: wsBtn.modelData === Hyprland.focusedWorkspace
                                      ? "#${palette.base00}" : "#${palette.base03}"
                                  font.pixelSize: 12
                                  font.family: "JetBrains Mono"
                                  font.bold: true
                              }

                              MouseArea {
                                  anchors.fill: parent
                                  onClicked: wsBtn.modelData.activate()
                              }
                          }
                      }
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                      id: clockText
                      color: "#${palette.base05}"
                      font.pixelSize: 13
                      font.family: "JetBrains Mono"
                      font.bold: true

                      Timer {
                          interval: 1000; running: true; repeat: true
                          onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd MMM dd  HH:mm")
                      }
                      Component.onCompleted: text = Qt.formatDateTime(new Date(), "ddd MMM dd  HH:mm")
                  }

                  Item { Layout.fillWidth: true }

                  Item {
                      id: volWidget
                      implicitWidth: volRow.implicitWidth
                      implicitHeight: 28

                      Row {
                          id: volRow
                          anchors.verticalCenter: parent.verticalCenter
                          spacing: 3

                          Text {
                              anchors.verticalCenter: parent.verticalCenter
                              font.pixelSize: 20
                              font.family: "JetBrainsMono Nerd Font Mono"
                              color: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "#${palette.base03}" : "#${palette.base05}"
                              text: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "󰸈" :
                                    (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 0.66 ? "󰕾" :
                                    (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 0.33 ? "󰖀" : "󰕿"
                          }

                          Text {
                              anchors.verticalCenter: parent.verticalCenter
                              font.pixelSize: 12
                              font.family: "JetBrains Mono"
                              color: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "#${palette.base03}" : "#${palette.base05}"
                              text: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "mute" :
                                    Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100) + "%"
                          }
                      }

                      MouseArea {
                          anchors.fill: parent
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          onClicked: mouse => {
                              if (mouse.button === Qt.RightButton) {
                                  pavuProcess.running = true
                              } else {
                                  const audio = Pipewire.defaultAudioSink?.audio
                                  if (audio) audio.muted = !audio.muted
                              }
                          }
                          onWheel: wheel => {
                              const audio = Pipewire.defaultAudioSink?.audio
                              if (!audio) return
                              const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                              audio.volume = Math.max(0.0, Math.min(1.5, audio.volume + delta))
                          }
                      }
                  }

                  Item {
                      id: netWidget
                      implicitWidth: 28
                      implicitHeight: 28

                      property string connType: "none"

                      Process {
                          id: netStatusProc
                          command: ["sh", "-c", "${pkgs.networkmanager}/bin/nmcli -t -f TYPE,STATE dev | grep ':connected' | head -1"]
                          running: true
                          property bool gotData: false
                          onRunningChanged: if (running) gotData = false
                          stdout: SplitParser {
                              onRead: line => {
                                  if (line.trim() !== "") {
                                      netStatusProc.gotData = true
                                      const t = line.split(":")[0].toLowerCase()
                                      netWidget.connType = t.includes("wifi") || t.includes("wireless") ? "wifi" : "ethernet"
                                  }
                              }
                          }
                          onExited: (code, status) => {
                              if (!gotData) netWidget.connType = "none"
                          }
                      }

                      Timer {
                          interval: 15000; running: true; repeat: true
                          onTriggered: if (!netStatusProc.running) netStatusProc.running = true
                      }

                      Process { id: netInfoProc; command: ["/etc/scripts/net-info.sh"] }
                      Process { id: nmEditorProc; command: ["${pkgs.networkmanagerapplet}/bin/nm-connection-editor"] }

                      Text {
                          anchors.centerIn: parent
                          font.pixelSize: 18
                          font.family: "JetBrainsMono Nerd Font Mono"
                          color: netWidget.connType === "none" ? "#${palette.base03}" : "#${palette.base05}"
                          text: netWidget.connType === "wifi" ? "󰤨" :
                                netWidget.connType === "ethernet" ? "󰈀" : "󰤭"
                      }

                      MouseArea {
                          anchors.fill: parent
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          onClicked: mouse => {
                              if (mouse.button === Qt.RightButton) {
                                  nmEditorProc.running = true
                              } else {
                                  netInfoProc.running = true
                              }
                          }
                      }
                  }

                  Repeater {
                      model: SystemTray.items
                      delegate: Item {
                          id: trayItem
                          required property SystemTrayItem modelData
                          implicitWidth: 22; implicitHeight: 22

                          Image {
                              anchors.centerIn: parent
                              width: 16; height: 16
                              source: trayItem.modelData.icon
                              smooth: true
                          }

                          MouseArea {
                              anchors.fill: parent
                              acceptedButtons: Qt.LeftButton | Qt.RightButton
                              onClicked: mouse => {
                                  if (mouse.button === Qt.RightButton)
                                      trayItem.modelData.secondaryActivate()
                                  else
                                      trayItem.modelData.activate()
                              }
                          }
                      }
                  }

                  Row {
                      id: batRow
                      visible: UPower.displayDevice !== null && UPower.displayDevice.ready
                      spacing: 3

                      Text {
                          anchors.verticalCenter: parent.verticalCenter
                          font.pixelSize: 14
                          font.family: "JetBrainsMono Nerd Font Mono"
                          color: (UPower.displayDevice !== null
                              && UPower.displayDevice.state !== UPowerDeviceState.Charging
                              && UPower.displayDevice.percentage <= 0.20) ? "#${palette.base08}" : "#${palette.base05}"
                          text: UPower.displayDevice === null ? "" :
                              (UPower.displayDevice.state === UPowerDeviceState.Charging
                               || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
                                  ? "󰂄" :
                              UPower.displayDevice.percentage <= 0.10 ? "󰂎" :
                              UPower.displayDevice.percentage <= 0.30 ? "󰁻" :
                              UPower.displayDevice.percentage <= 0.50 ? "󰁽" :
                              UPower.displayDevice.percentage <= 0.70 ? "󰁿" :
                              UPower.displayDevice.percentage <= 0.90 ? "󰂁" : "󰁹"
                      }

                      Text {
                          anchors.verticalCenter: parent.verticalCenter
                          font.pixelSize: 12
                          font.family: "JetBrains Mono"
                          color: (UPower.displayDevice !== null
                              && UPower.displayDevice.state !== UPowerDeviceState.Charging
                              && UPower.displayDevice.percentage <= 0.20) ? "#${palette.base08}" : "#${palette.base05}"
                          text: UPower.displayDevice === null ? "" :
                                Math.round((UPower.displayDevice.percentage ?? 0) * 100) + "%"
                      }
                  }
              }
          }
        '';

        ".config/quickshell/Notifications.qml".text = ''
          pragma ComponentBehavior: Bound
          import Quickshell
          import Quickshell.Services.Notifications
          import QtQuick
          import QtQuick.Layouts

          Scope {
              NotificationServer {
                  id: server
                  keepOnReload: true
              }

              PanelWindow {
                  anchors { top: true; right: true }
                  margins { top: 44; right: 8 }

                  visible: server.trackedNotifications.length > 0
                  implicitWidth: 360
                  implicitHeight: Math.max(notifCol.implicitHeight + 16, 1)
                  color: "transparent"

                  ColumnLayout {
                      id: notifCol
                      anchors { fill: parent; margins: 8 }
                      spacing: 8

                      Repeater {
                          model: server.trackedNotifications
                          delegate: Rectangle {
                              id: notif
                              required property Notification modelData

                              Layout.fillWidth: true
                              implicitHeight: notifInner.implicitHeight + 20
                              color: "#eb${palette.base00}"
                              border.color: "#${palette.base0D}"
                              border.width: 1
                              radius: 4

                              ColumnLayout {
                                  id: notifInner
                                  anchors { fill: parent; margins: 10 }
                                  spacing: 4

                                  Text {
                                      text: notif.modelData.summary
                                      color: "#${palette.base05}"
                                      font.pixelSize: 13
                                      font.family: "JetBrains Mono"
                                      font.bold: true
                                      Layout.fillWidth: true
                                      elide: Text.ElideRight
                                  }

                                  Text {
                                      text: notif.modelData.body
                                      color: "#${palette.base04}"
                                      font.pixelSize: 12
                                      font.family: "JetBrains Mono"
                                      Layout.fillWidth: true
                                      wrapMode: Text.WordWrap
                                      visible: text.length > 0
                                  }
                              }

                              MouseArea {
                                  anchors.fill: parent
                                  onClicked: notif.modelData.dismiss()
                              }

                              Timer {
                                  interval: notif.modelData.expireTimeout > 0
                                      ? notif.modelData.expireTimeout : 3000
                                  running: true
                                  onTriggered: notif.modelData.dismiss()
                              }
                          }
                      }
                  }
              }
          }
        '';
      };
    };
  };
}
