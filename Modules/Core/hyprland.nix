{ inputs, ... }: {
  flake.nixosModules.Tn-hyprland = { pkgs, config, lib, ... }:
  let
    nixosCfg = config;

    hyprlandPkg = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    wlKbptr = pkgs.wl-kbptr.overrideAttrs (oldAttrs: {
      mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dopencv=enabled" ];
      buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.opencv ];
    });

    vimEdit = pkgs.writeShellScript "vim-edit" ''
      ${pkgs.wtype}/bin/wtype -M ctrl -k a
      sleep 0.15
      ${pkgs.wtype}/bin/wtype -M ctrl -k c
      sleep 0.15

      export TMPFILE=$(mktemp /tmp/vim-edit-XXXXXX.md)
      ${pkgs.wl-clipboard}/bin/wl-paste > "$TMPFILE"

      ghostty --title=vim-edit -e bash -c \
        'nvim "$TMPFILE"; ${pkgs.wl-clipboard}/bin/wl-copy < "$TMPFILE"; rm -f "$TMPFILE"
         ${pkgs.libnotify}/bin/notify-send "Edited text copied" "Paste it back with Ctrl+V"'
    '';

    wayscrollshot =
      (inputs.wayscrollshot.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ../../patches/wayscrollshot-max-preview-height.patch ];
      }));

    scrollshot = pkgs.writeShellScript "scrollshot" ''
      ${wayscrollshot}/bin/wayscrollshot --clipboard --max-preview-height 36 && \
        ${pkgs.libnotify}/bin/notify-send "Scrolling screenshot copied" "On the clipboard"
    '';

    # hyprpicker prints the picked colour (and -a copies it); nothing on cancel
    colorPick = pkgs.writeShellScript "tn-color-pick" ''
      COLOR=$(${pkgs.hyprpicker}/bin/hyprpicker -a)
      [ -n "$COLOR" ] && ${pkgs.libnotify}/bin/notify-send "Colour copied" "$COLOR"
    '';

    # The bar has no mic indicator, so say which way the toggle went
    micMute = pkgs.writeShellScript "tn-mic-mute" ''
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Microphone muted"
      else
        ${pkgs.libnotify}/bin/notify-send -t 2000 "Microphone on"
      fi
    '';

    tnShowKeybindings = pkgs.writeShellScript "tn-show-keybindings"
      (builtins.readFile ../../bin/tn-show-keybindings);

    # Needs node on PATH: math-snippets.js is JS (replacements may be
    # functions), so it is eval'd rather than parsed.
    tnShowSnippets = pkgs.writeShellScript "tn-show-snippets" ''
      export PATH="${pkgs.nodejs}/bin:${pkgs.wofi}/bin:$PATH"
      ${builtins.readFile ../../bin/tn-show-snippets}
    '';

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

    # Focus the previously focused window: `ws` limits it to the active
    # workspace, `global` takes it from anywhere (switching workspace).
    focusPrev = pkgs.writeShellScript "tn-focus-prev" ''
      WS_ID=$(${hyprlandPkg}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq '.id')
      ADDR=$(${hyprlandPkg}/bin/hyprctl clients -j | \
        ${pkgs.jq}/bin/jq -r --arg scope "$1" --argjson ws "$WS_ID" '
          map(select(.focusHistoryID != 0 and ($scope == "global" or .workspace.id == $ws))) |
          sort_by(.focusHistoryID) | .[0].address // empty')
      [ -z "$ADDR" ] && exit 0
      ${hyprlandPkg}/bin/hyprctl eval "hl.dispatch(hl.dsp.focus({window='address:$ADDR'}))"
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

    # region|full: a slurp selection or the focused monitor, sent to the
    # clipboard or saved to ~/Downloads (Shift = save, Alt = full screen).
    screenshot = pkgs.writeShellScript "tn-screenshot" ''
      set -eu
      mode="$1" dest="$2"   # region|full  clip|save|both
      file="$HOME/Downloads/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"
      tmp=$(mktemp --suffix=.png)
      trap 'rm -f "$tmp"' EXIT

      if [ "$mode" = region ]; then
        geom=$(${pkgs.slurp}/bin/slurp) || exit 0
        ${pkgs.grim}/bin/grim -g "$geom" "$tmp"
      else
        mon=$(${hyprlandPkg}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')
        ${pkgs.grim}/bin/grim -o "$mon" "$tmp"
      fi

      case "$dest" in clip|both) ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$tmp" ;; esac
      case "$dest" in
        save|both)
          mkdir -p "$HOME/Downloads"
          cp "$tmp" "$file"
          ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$(basename "$file")" ;;
        clip)
          ${pkgs.libnotify}/bin/notify-send "Screenshot copied" "On the clipboard" ;;
      esac
    '';

    pkillMenu = pkgs.writeShellScript "tn-pkill-menu" ''
      CHOICE=$(${pkgs.procps}/bin/ps -u "$USER" -o comm= | sort -u | \
        ${pkgs.wofi}/bin/wofi --dmenu --no-sort -p "pkill")
      [ -z "$CHOICE" ] && exit 0
      pkill -i -x "$CHOICE"
    '';

    # Pick a saved value by label, type it into the focused window, and leave
    # it on the clipboard as well. The list lives outside the repo on purpose,
    # since it holds personal details (student number etc.).
    quickPaste = pkgs.writeShellScript "tn-quick-paste" ''
      FILE="$HOME/.config/tn/quick-paste"
      if [ ! -f "$FILE" ]; then
        mkdir -p "$(dirname "$FILE")"
        printf '%s\n' \
          '# label = value   (one per line; split at the first " = ")' \
          'student number = 00000000' > "$FILE"
        ${pkgs.libnotify}/bin/notify-send "Quick paste" "Created $FILE, add your entries there"
        exit 0
      fi

      LABEL=$(grep -v '^\s*\(#\|$\)' "$FILE" | sed 's/ = .*//' | \
        ${pkgs.wofi}/bin/wofi --dmenu --insensitive -p "paste")
      [ -z "$LABEL" ] && exit 0

      VALUE=$(LABEL="$LABEL" ${pkgs.gawk}/bin/awk '
        !/^[[:space:]]*#/ && (i = index($0, " = ")) && substr($0, 1, i - 1) == ENVIRON["LABEL"] {
          print substr($0, i + 3); exit
        }' "$FILE")
      [ -z "$VALUE" ] && exit 0

      printf '%s' "$VALUE" | ${pkgs.wl-clipboard}/bin/wl-copy
      # let focus return to the previous window before typing
      sleep 0.15
      ${pkgs.wtype}/bin/wtype -- "$VALUE"
    '';

    # Same flow as quick paste, over every fully-qualified emoji ("😀 grinning
    # face"), so the picker searches by name. The list is built once from the
    # Unicode data instead of being fetched at runtime.
    emojiList = pkgs.runCommand "tn-emoji-list" { } ''
      sed -n 's/^[^#]*; fully-qualified *# \([^ ]*\) E[0-9.]* \(.*\)$/\1 \2/p' \
        ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt > $out
    '';
    emojiPick = pkgs.writeShellScript "tn-emoji-pick" ''
      EMOJI=$(${pkgs.wofi}/bin/wofi --dmenu --insensitive -p "emoji" < ${emojiList} | cut -d' ' -f1)
      [ -z "$EMOJI" ] && exit 0
      printf '%s' "$EMOJI" | ${pkgs.wl-clipboard}/bin/wl-copy
      # let focus return to the previous window, then paste from the clipboard.
      # Typing it with wtype doesn't work for emoji: most apps drop the
      # multi-codepoint ones (skin tones, ZWJ sequences, variation selectors).
      sleep 0.15
      CLASS=$(${hyprlandPkg}/bin/hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class // ""')
      case "$CLASS" in
        com.mitchellh.ghostty) ${pkgs.wtype}/bin/wtype -M ctrl -M shift -k v ;;
        *)                     ${pkgs.wtype}/bin/wtype -M ctrl -k v ;;
      esac
    '';

  in {

    programs.hyprland.enable = true;
    programs.hyprland.package = hyprlandPkg;
    programs.hyprlock.enable = true;

    environment.systemPackages = with pkgs; [
      wlKbptr
      wofi
      xdg-terminal-exec   # lets xdg-open/gio launch Terminal=true apps (nvim.desktop) in ghostty
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
        enable     = true;
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

      # the terminal xdg-terminal-exec opens Terminal=true desktop entries in
      xdg.configFile."xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";

      # Keyboard pointer. Super+G: hint mode (OpenCV finds clickable things,
      # type a label to click it). Super+Shift+G: tile grid, then bisect to
      # refine; g/h/b = left/right/middle click (by key position).
      xdg.configFile."wl-kbptr/config".text = ''
        [general]
        modes=tile,bisect

        [mode_tile]
        label_color=#${palette.base05}ff
        label_select_color=#${palette.base0D}ff
        unselectable_bg_color=#${palette.base00}66
        selectable_bg_color=#${palette.base0D}22
        selectable_border_color=#${palette.base0D}88
        label_font_family=JetBrainsMono Nerd Font

        [mode_floating]
        label_color=#${palette.base00}ff
        label_select_color=#${palette.base0D}ff
        unselectable_bg_color=#${palette.base00}44
        selectable_bg_color=#${palette.base0A}dd
        selectable_border_color=#${palette.base0A}ff
        label_font_family=JetBrainsMono Nerd Font

        [mode_bisect]
        label_font_family=JetBrainsMono Nerd Font
        pointer_color=#${palette.base08}dd
      '';

      home.file.".local/share/tn/bin/tn-show-snippets" = {
        source     = tnShowSnippets;
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
          matching     = "fuzzy";
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

      # App launcher (Super+Space). Ranks by match quality, then launch count,
      # so among equally good partial matches the most-used app wins. wofi
      # stays for the dmenu-style pickers above.
      programs.fuzzel = {
        enable = true;
        settings = {
          main = {
            font            = "JetBrainsMono Nerd Font:size=18";
            terminal        = "ghostty -e";
            icon-theme      = "Adwaita";
            # no filename: "youtube-music.desktop" would match "youtube"
            fields          = "name,generic,keywords";
            width           = 50;
            lines           = 12;
            horizontal-pad  = 24;
            vertical-pad    = 16;
            inner-pad       = 12;
            prompt          = "\"❯ \"";
            layer           = "overlay";
          };
          colors = {
            background      = "${palette.base00}ff";
            text            = "${palette.base05}ff";
            prompt          = "${palette.base0D}ff";
            input           = "${palette.base05}ff";
            placeholder     = "${palette.base03}ff";
            match           = "${palette.base0D}ff";
            selection       = "${palette.base02}ff";
            selection-text  = "${palette.base0D}ff";
            selection-match = "${palette.base0E}ff";
            counter         = "${palette.base03}ff";
            border          = "${palette.base03}ff";
          };
          border = {
            width            = 1;
            radius           = 4;
            selection-radius = 4;
          };
        };
      };

      programs.ghostty = {
        enable = true;
        settings = {
          font-family           = nixosCfg.tn.primary_font;
          font-size             = 12;
          "window-decoration"   = "none";
          theme                 = "tn";
          keybind               = [
            "ctrl+k=reset"
            "ctrl+shift+e=write_scrollback_file:open"
          ];
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
            # hl.dsp.dpms() IGNORES its argument in Hyprland 0.56 -- it is
            # toggle-only -- and monitor.dpms_status is read-only, so there is
            # no "turn the panel on" primitive to call here. The old
            # dpms('on') therefore TOGGLED the panel OFF on every resume, and
            # with both dpms wake options below defaulting to false that left
            # a black screen recoverable only by a hard reboot.
            # So: toggle only when a monitor is actually off, making this a
            # no-op on a panel that resumed fine. Verified both ways on Kvasir.
            after_sleep_cmd  = "hyprctl eval \"local off=false for _,m in ipairs(hl.get_monitors()) do if not m.dpms_status then off=true end end if off then hl.dispatch(hl.dsp.dpms(0)) end\"";
          };
          # No idle listeners: the screen never blanks or auto-locks on idle.
          # Locking/DPMS on real suspend is still handled by general.* above.
          listener = [ ];
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
            name      = "habitica-workspace",
            match     = { class = "brave-habitica.com__-Default" },
            workspace = 9,
          })

          hl.window_rule({
            name   = "portal-dialog-size",
            match  = { class = "xdg-desktop-portal-gtk" },
            float  = true,
            size   = "860 600",
            center = true,
          })

          -- Bitwarden's extension pop-out (Brave class
          -- brave-<ext-id>__popup_index.html-Default). Tiled, it is stretched
          -- to a full-width column and renders half-drawn until a redraw.
          hl.window_rule({
            name     = "bitwarden-popout",
            match    = { class = ".*nngceckbapebfimnlniiiahkandclblb.*" },
            float    = true,
            max_size = "480 650",
            center   = true,
          })

          hl.window_rule({
            name   = "qalculate-scratchpad",
            match  = { class = "qalculate-gtk" },
            float  = true,
            size   = "800 500",
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
            name  = "pavucontrol-float",
            match = { class = "org.pulseaudio.pavucontrol" },
            float = true,
          })

          hl.window_rule({
            name  = "blueman-float",
            match = { class = ".*blueman-manager.*" },
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
            hl.exec_cmd("nm-applet --indicator")
            hl.exec_cmd("wl-clip-persist --clipboard regular")
            hl.exec_cmd("clipse -listen")
            hl.exec_cmd("hyprsunset")
            hl.exec_cmd("${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent")
            hl.exec_cmd("fcitx5 -d --replace")
            hl.exec_cmd("[workspace 8 silent] obsidian")
            -- hl.exec_cmd("env QT_QPA_PLATFORM=xcb plover")
            hl.exec_cmd("[workspace 9 silent] ${pkgs.brave}/bin/brave --app=https://habitica.com --start-maximized")
          end)

          -- Trackpad gestures. Three fingers sideways pans the scrolling
          -- tape (window to window), four fingers switches workspace, three
          -- fingers up toggles fullscreen.
          hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
          hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
          hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })

          hl.config({
            input = {
              kb_layout                 = "us",
              -- Focus follows the cursor. The reverse (cursor follows focus)
              -- is the cursor.* warp settings below.
              follow_mouse              = 1,
              float_switch_override_focus = 0,
              sensitivity               = 0,
              touchpad = {
                natural_scroll      = true,
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
              layout = "scrolling",
            },
            scrolling = {
              -- Columns are full-width by default; SUPER+left/right
              -- scrolls through them one screen at a time, so the workflow
              -- still reads as "one window at a time" like monocle did, but
              -- with the whole workspace laid out on a tape behind it.
              column_width = 1.0,
              -- SUPER+SHIFT+W cycles this list with `colresize +conf`, so a
              -- two-entry list is exactly a full-width <-> half-width toggle.
              explicit_column_widths = "0.5, 1.0",
              fullscreen_on_one_column = true,
              -- Focusing a window (incl. from the SUPER+B pickers) scrolls
              -- the tape to bring it on screen.
              follow_focus = true,
              focus_fit_method = 1,
              -- Wrap at the ends, matching the old monocle cyclenext/cycleprev.
              wrap_focus = true,
              wrap_swapcol = true,
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
              -- Keyboard focus changes (scrolling-layout focus, the window
              -- pickers, workspace switches) move the cursor to the newly
              -- focused window, so it is always over what has focus.
              no_warps                 = false,
              warp_on_change_workspace = 1,
            },
            misc = {
              disable_hyprland_logo    = true,
              disable_splash_rendering = true,
              background_color         = "rgb(${palette.base00})",
              -- Escape hatch: if the panel ever ends up DPMS-off unexpectedly
              -- (bad resume, stray dpms toggle), let input wake it back up
              -- rather than leaving a black screen that needs a hard reboot.
              key_press_enables_dpms   = true,
              mouse_move_enables_dpms  = true,
              -- If hyprlock dies while holding the ext-session-lock, let a new
              -- lock client attach instead of stranding the session locked
              -- forever with nothing able to accept a password.
              allow_session_lock_restore = true,
            },
            ecosystem = {
              no_update_news = true,
            },
          })

          hl.bind(mainMod .. " + Space",      hl.dsp.exec_cmd("fuzzel"))
          hl.bind(mainMod .. " + T",          hl.dsp.exec_cmd(terminal))
          hl.bind(mainMod .. " + S",          hl.dsp.exec_cmd("brave"))
          hl.bind(mainMod .. " + D",          hl.dsp.window.close())
          hl.bind(mainMod .. " + SHIFT + D",  hl.dsp.exec_cmd("${pkillMenu}"))
          hl.bind(mainMod .. " + Q",          hl.dsp.exec_cmd("hyprlock"))
          hl.bind(mainMod .. " + SHIFT + Q",  hl.dsp.exec_cmd("${pkgs.systemd}/bin/systemd-run --user --no-block --collect /etc/scripts/clean-power-off.sh"))
          hl.bind(mainMod .. " + F",          hl.dsp.exec_cmd("ghostty -e yazi $HOME"))
          hl.bind(mainMod .. " + ALT + F",    hl.dsp.exec_cmd("nemo"))
          hl.bind(mainMod .. " + 0",          hl.dsp.exec_cmd("ghostty --title=grimoire-inbox -e nvim $HOME/Grimoire/Inbox.md"))
          hl.bind(mainMod .. " + SHIFT + 0",  hl.dsp.exec_cmd("ghostty --title=technonomicon -e nvim $HOME/Projects/Technonomicon/README.md"))
          hl.bind(mainMod .. " + Return",      hl.dsp.exec_cmd("${vimEdit}"))
          hl.bind(mainMod .. " + E",          hl.dsp.exec_cmd("xdg-open 'obsidian://advanced-uri?vault=Grimoire&commandid=periodic-notes%3Aopen-daily-note&openmode=window'"))
          hl.bind(mainMod .. " + H",          hl.dsp.exec_cmd("$HOME/.local/share/tn/bin/tn-show-keybindings"))
          hl.bind(mainMod .. " + SHIFT + H",  hl.dsp.exec_cmd("$HOME/.local/share/tn/bin/tn-show-snippets"))
          hl.bind(mainMod .. " + X",          hl.dsp.exec_cmd("ghostty --class=clipse -e clipse"))
          hl.bind(mainMod .. " + SHIFT + X",  hl.dsp.exec_cmd("${quickPaste}"))
          hl.bind(mainMod .. " + ALT + X",    hl.dsp.exec_cmd("${emojiPick}"))
          hl.bind(mainMod .. " + SHIFT + ALT + X", hl.dsp.exec_cmd("ghostty --title=quick-paste -e nvim $HOME/.config/tn/quick-paste"))
          hl.bind(mainMod .. " + semicolon",  hl.dsp.window.float())
          hl.bind(mainMod .. " + Tab",        hl.dsp.exec_cmd("${focusPrev} ws"))
          hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("${focusPrev} global"))
          hl.bind(mainMod .. " + comma",      hl.dsp.focus({ workspace = "r+1" }))
          hl.bind(mainMod .. " + minus",      hl.dsp.window.resize({ x = -100, y =    0, relative = true }))
          hl.bind(mainMod .. " + equal",      hl.dsp.window.resize({ x =  100, y =    0, relative = true }))
          hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
          hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y =  100, relative = true }))

          hl.bind(mainMod .. " + ALT + G",    hl.dsp.exec_cmd("${pkgs.brave}/bin/brave --app=https://gemini.google.com/app --start-maximized"))
          hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd("qalculate-gtk"))
          hl.bind(mainMod .. " + ALT + C",    hl.dsp.exec_cmd("geogebra"))
          hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd("xdg-open 'obsidian://advanced-uri?vault=Grimoire&filepath=Home.md&openmode=window'"))
          hl.bind(mainMod .. " + ALT + N",    hl.dsp.exec_cmd("obsidian"))
          hl.bind(mainMod .. " + ALT + A",    hl.dsp.exec_cmd("anki"))
          hl.bind(mainMod .. " + Print",      hl.dsp.exec_cmd("${colorPick}"))

          -- Focus: left/right walks the scroll order, up/down walks the
          -- windows stacked inside the focused column.
          hl.bind(mainMod .. " + left",  hl.dsp.layout("focus l"))
          hl.bind(mainMod .. " + right", hl.dsp.layout("focus r"))
          hl.bind(mainMod .. " + up",    hl.dsp.layout("focus u"))
          hl.bind(mainMod .. " + down",  hl.dsp.layout("focus d"))

          -- Move: left/right reorders the window in the scroll order,
          -- up/down reorders it inside its column.
          hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.layout("swapcol l"))
          hl.bind(mainMod .. " + SHIFT + right", hl.dsp.layout("swapcol r"))
          hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up"   }))
          hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

          -- Side by side vs. one at a time. Columns are separate windows on
          -- the tape, so "split vertically" is just making every column half
          -- width; it is not a consume operation.
          --
          -- `colresize all` must be paired with `fit_into_view`: its branch in
          -- ScrollingAlgorithm returns before the scope guard that re-fits the
          -- column, so it resizes without touching the camera offset and
          -- leaves the focused window scrolled off-screen. hl.bind takes a
          -- function as well as a dispatcher, so the two go in one bind.
          local function colWidthAll(width)
            return function()
              hl.dispatch(hl.dsp.layout("colresize all " .. width))
              hl.dispatch(hl.dsp.layout("fit_into_view"))
            end
          end

          hl.bind(mainMod .. " + ALT + right", colWidthAll("0.5"))
          hl.bind(mainMod .. " + ALT + left",  colWidthAll("1.0"))

          -- Stack the focused window into a neighbouring column / pull it back
          -- out into one of its own. Windows inside a column stack top to
          -- bottom, so this lives on the vertical arrows. prev/next still mean
          -- the column to the left/right: up works leftward, down rightward.
          hl.bind(mainMod .. " + ALT + up",   hl.dsp.layout("consume_or_expel prev"))
          hl.bind(mainMod .. " + ALT + down", hl.dsp.layout("consume_or_expel next"))

          for i = 1, 9 do
            hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
            hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
          end

          hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
          hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
          hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
          hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("${micMute}"))
          hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 10%+"))
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))

          hl.bind("Print",                   hl.dsp.exec_cmd("${screenshot} region clip"))
          hl.bind(mainMod .. " + Y",         hl.dsp.exec_cmd("${screenshot} region clip"))
          hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd("${screenshot} region save"))
          hl.bind(mainMod .. " + ALT + Y",         hl.dsp.exec_cmd("${screenshot} full clip"))
          hl.bind(mainMod .. " + SHIFT + ALT + Y", hl.dsp.exec_cmd("${screenshot} full save"))

          -- English <-> Pinyin. Bound here rather than as an fcitx hotkey,
          -- which only fires while a text field has focus.
          hl.bind(mainMod .. " + Escape",    hl.dsp.exec_cmd("fcitx5-remote -t"))

          hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("wl-kbptr -o modes=floating,click -o mode_floating.source=detect"))
          hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("wl-kbptr -o modes=tile,bisect"))
          hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("${winPickerWs}"))
          hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("${winPicker}"))
          hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("${winPull}"))

          hl.bind(mainMod .. " + SHIFT + W", hl.dsp.layout("colresize +conf"))
          hl.bind(mainMod .. " + ALT + W",   hl.dsp.layout("fit visible"))
          hl.bind(mainMod .. " + CTRL + W",  hl.dsp.layout("center"))

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
          // Without a theme Qt only searches hicolor, so tray icons that live
          // in Adwaita (fcitx5's English "input-keyboard") drew as the
          // magenta missing-image checkerboard.
          //@ pragma IconTheme Adwaita
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
                          visible: modelData.id > 0
                          implicitWidth: modelData.id > 0 ? 28 : 0
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

                      // nm-applet's own menu (networks, VPNs, "Edit Connections"),
                      // opened under this icon. nm-applet is hidden from the tray
                      // below so it isn't shown twice.
                      function openNmMenu() {
                          const items = SystemTray.items.values
                          for (let i = 0; i < items.length; i++) {
                              if (items[i].id === "nm-applet" && items[i].hasMenu) {
                                  const pos = netWidget.mapToItem(null, 0, 0)
                                  items[i].display(root, pos.x, root.implicitHeight)
                                  return
                              }
                          }
                          nmEditorProc.running = true   // applet not running
                      }

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
                          // left: network menu, right: connection info
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          onClicked: mouse => {
                              if (mouse.button === Qt.RightButton) {
                                  netInfoProc.running = true
                              } else {
                                  netWidget.openNmMenu()
                              }
                          }
                      }
                  }

                  Repeater {
                      model: SystemTray.items
                      delegate: Item {
                          id: trayItem
                          required property SystemTrayItem modelData
                          visible: modelData.id !== "nm-applet"
                          implicitWidth: visible ? 22 : 0; implicitHeight: 22

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
                  // Only tracked notifications land in trackedNotifications;
                  // without this every incoming one is dropped unseen.
                  onNotification: notification => notification.tracked = true
              }

              PanelWindow {
                  anchors { top: true; right: true }
                  margins { top: 44; right: 8 }

                  visible: server.trackedNotifications.values.length > 0
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
