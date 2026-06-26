{ ... }: {
  home.file.".config/hypr/hyprland.lua".text = ''
    -- ── Monitor ──────────────────────────────────────────────────────────────────
    -- Akmon:  hl.monitor({ output = "DP-1",  mode = "2560x1440@144", position = "0x0", scale = 1 })
    -- Kvasir: hl.monitor({ output = "eDP-1", mode = "2560x1440@60",  position = "0x0", scale = 1.5 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

    -- ── Autostart ────────────────────────────────────────────────────────────────
    hl.on("hyprland.start", function()
        hl.exec_cmd("mako")
        hl.exec_cmd("hyprpaper")
        hl.exec_cmd("waybar")
        hl.exec_cmd("ghostty --class=ghostty-scratchpad")
        hl.exec_cmd("ghostty --class=ghostty-nvim -e nvim")
        hl.exec_cmd("udiskie")
        hl.exec_cmd("copyq")
        hl.exec_cmd("fcitx5 -d")
        hl.exec_cmd("aw-server")
        hl.exec_cmd("aw-watcher-window")
        hl.exec_cmd("aw-watcher-afk")
    end)

    -- ── Config ───────────────────────────────────────────────────────────────────
    hl.config({
        general = {
            gaps_in     = 4,
            gaps_out    = 8,
            border_size = 2,
            col = {
                active_border   = "rgba(00FFFFee)",
                inactive_border = "rgba(1D232Faa)",
            },
            layout = "dwindle",
        },
        decoration = {
            rounding = 6,
            blur = {
                enabled = true,
                size    = 4,
                passes  = 2,
            },
        },
        animations = {
            enabled = true,
        },
        misc = {
            disable_hyprland_logo    = true,
            disable_splash_rendering = true,
        },
        input = {
            kb_layout    = "us",
            repeat_delay = 500,
            repeat_rate  = 30,
            touchpad = {
                natural_scroll          = false,
                tap_to_click            = true,
                disable_while_typing    = true,
                middle_button_emulation = false,
            },
        },
        cursor = {
            hide_on_key_press = true,
            inactive_timeout  = 5,
        },
        xwayland = {
            force_zero_scaling = true,
        },
    })

    -- ── Animations ───────────────────────────────────────────────────────────────
    hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "snappy" })
    hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "snappy" })

    -- ── Window Rules ─────────────────────────────────────────────────────────────
    hl.window_rule({
        match     = { class = "^ghostty-scratchpad$" },
        workspace = "special:terminal silent",
        float     = true,
        size      = "65% 60%",
        center    = true,
    })

    hl.window_rule({
        match     = { class = "^ghostty-nvim$" },
        workspace = "name:nvim silent",
    })

    hl.window_rule({ match = { class = "^pavucontrol$" },     float = true })
    hl.window_rule({ match = { class = "^blueman-manager$" }, float = true })
    hl.window_rule({ match = { class = "^wl-kbptr$" },        float = true })

    -- ── Keybindings ──────────────────────────────────────────────────────────────
    local mod = "SUPER"

    -- Workspaces 1–9
    for i = 1, 9 do
        hl.bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
        hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    end

    -- Named workspace: Neovim (Space = code:57)
    hl.bind(mod .. " + code:57", hl.dsp.focus({ workspace = "name:nvim" }))

    -- Window management
    hl.bind(mod .. " + D",         hl.dsp.window.close())
    hl.bind(mod .. " + W",         hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximize",   action = "toggle" }))

    -- Launch
    hl.bind(mod .. " + Return", hl.dsp.exec_cmd("anyrun"))
    hl.bind(mod .. " + T",      hl.dsp.exec_cmd("ghostty"))
    hl.bind(mod .. " + grave",  hl.dsp.workspace.toggle_special("terminal"))

    -- System
    hl.bind(mod .. " + Q",         hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("wlogout"))

    -- Screenshot / screen tools
    hl.bind(mod .. " + Y",         hl.dsp.exec_cmd("slurp | grim -g - - | wl-copy"))
    hl.bind(mod .. " + SHIFT + Y", hl.dsp.exec_cmd("hyprshot -m region"))
    hl.bind(mod .. " + CTRL + Y",  hl.dsp.exec_cmd("wf-recorder"))
    hl.bind(mod .. " + P",         hl.dsp.exec_cmd("hyprpicker"))

    -- Keyboard pointer
    hl.bind(mod .. " + K", hl.dsp.exec_cmd("wl-kbptr"))

    -- Focus navigation (Colemak-DH home row: m/n/e/i = ←/↓/↑/→)
    hl.bind(mod .. " + m", hl.dsp.focus({ direction = "left" }))
    hl.bind(mod .. " + i", hl.dsp.focus({ direction = "right" }))
    hl.bind(mod .. " + n", hl.dsp.focus({ direction = "down" }))
    hl.bind(mod .. " + e", hl.dsp.focus({ direction = "up" }))

    -- Move windows
    hl.bind(mod .. " + SHIFT + m", hl.dsp.window.move({ direction = "left" }))
    hl.bind(mod .. " + SHIFT + i", hl.dsp.window.move({ direction = "right" }))
    hl.bind(mod .. " + SHIFT + n", hl.dsp.window.move({ direction = "down" }))
    hl.bind(mod .. " + SHIFT + e", hl.dsp.window.move({ direction = "up" }))

    -- Resize (repeating)
    hl.bind(mod .. " + ALT + m", hl.dsp.window.resize({ x = -40, y =   0 }), { repeating = true })
    hl.bind(mod .. " + ALT + i", hl.dsp.window.resize({ x =  40, y =   0 }), { repeating = true })
    hl.bind(mod .. " + ALT + n", hl.dsp.window.resize({ x =   0, y =  40 }), { repeating = true })
    hl.bind(mod .. " + ALT + e", hl.dsp.window.resize({ x =   0, y = -40 }), { repeating = true })
  '';

  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;

      background = [{
        monitor = "";
        blur_passes = 3;
        blur_size = 8;
        noise = 0.012;
        contrast = 0.89;
        brightness = 0.72;
      }];

      input-field = [{
        size = "320, 52";
        outline_thickness = 2;
        outer_color = "rgb(00FFFF)";
        inner_color = "rgb(1D232F)";
        font_color = "rgb(CFDFDF)";
        fade_on_empty = true;
        placeholder_text = "";
        dots_center = true;
        check_color = "rgb(00FA9A)";
        fail_color = "rgb(FF5370)";
        position = "0, -120";
        halign = "center";
        valign = "center";
      }];

      label = [
        {
          text = "$TIME";
          font_size = 72;
          font_family = "JetBrains Mono";
          color = "rgba(CFDFDFee)";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
        {
          text = "cmd[update:60000] date '+%A, %B %d %Y'";
          font_size = 18;
          color = "rgba(8C98A6cc)";
          position = "0, 20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      modules-left  = [ "hyprland/workspaces" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right = [ "tray" "wireplumber" "network" "cpu" "memory" "battery" "backlight" ];

      "hyprland/workspaces" = {
        format = "{id}";
        on-click = "activate";
      };
      "hyprland/window".max-length = 60;

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%A, %B %d %Y}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      tray.spacing = 8;

      wireplumber = {
        format = "  {volume}%";
        format-muted = " ";
        on-click = "pavucontrol";
        max-volume = 150;
        scroll-step = 5;
      };

      network = {
        format-wifi = "  {essid}";
        format-ethernet = " {ifname}";
        format-disconnected = "󰌙 ";
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
      };

      cpu = {
        format = " {usage}%";
        interval = 5;
      };

      memory = {
        format = " {used:0.1f}G";
        interval = 10;
      };

      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = { warning = 30; critical = 15; };
      };

      backlight = {
        format = "{icon} {percent}%";
        format-icons = [ "" "" "" ];
      };
    }];

    style = ''
      * {
        font-family: "Iosevka", "Symbols Nerd Font";
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        background-color: #1D232F;
        color: #CFDFDF;
        border-bottom: 2px solid #00FFFF;
      }
      .modules-left, .modules-center, .modules-right {
        padding: 0 8px;
      }
      #workspaces button {
        padding: 0 6px;
        color: #8C98A6;
        border: none;
        border-bottom: 2px solid transparent;
      }
      #workspaces button.active {
        color: #00FFFF;
        border-bottom-color: #00FFFF;
      }
      #clock { color: #00FFFF; }
      #cpu, #memory, #battery, #backlight, #network, #wireplumber { color: #8C98A6; }
      #tray { color: #CFDFDF; }
    '';
  };
}
