{ inputs, ... }: {
  flake.nixosModules.Tn-hyprland = { pkgs, ... }:
  let
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
  in {

    programs.hyprland.enable = true;
    programs.hyprlock.enable = true;

    xdg.portal.extraPortals  = [ pkgs.xdg-desktop-portal-hyprland ];
    xdg.portal.configPackages = [ pkgs.xdg-desktop-portal-hyprland ];

    environment.systemPackages = with pkgs; [
      anyrun
      hypridle
      bibata-cursors
      quickshell
      networkmanagerapplet
      udiskie
      copyq
    ];

    home-manager.users.xin = {

      home.pointerCursor = {
        package    = pkgs.bibata-cursors;
        name       = "Bibata-Modern-Classic";
        size       = 24;
        gtk.enable = true;
        x11.enable = true;
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

          hl.env("XCURSOR_SIZE",  "24")
          hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
          hl.env("HYPRCURSOR_SIZE", "24")

          hl.config({ ['xwayland.force_zero_scaling'] = true })

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
            name   = "vim-edit-float",
            match  = { title = "vim-edit" },
            float  = true,
            size   = "900 600",
            center = true,
          })

          hl.on("hyprland.start", function()
            hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE GDK_BACKEND")
            hl.exec_cmd("hypridle")
            hl.exec_cmd("quickshell")
            hl.exec_cmd("nm-applet --indicator")
            hl.exec_cmd("udiskie --tray")
            hl.exec_cmd("blueman-applet")
            hl.exec_cmd("copyq --start-server")
            hl.exec_cmd("obsidian")
            hl.exec_cmd("[workspace 9 silent] flatpak run com.discordapp.Discord")
          end)

          hl.config({
            input = {
              kb_layout    = "us",
              follow_mouse = 1,
              touchpad     = { natural_scroll = true, disable_while_typing = true, drag_lock = false },
            },
            general = {
              gaps_in     = 5,
              gaps_out    = 0,
              border_size = 2,
              col = {
                active_border   = "rgba(00ffffee)",
                inactive_border = "rgba(595959aa)",
              },
              layout = "scrolling",
            },
            decoration = {
              rounding = 8,
            },
            scrolling = {
              fullscreen_on_one_column = true,
              explicit_column_widths   = "0.5, 1.0",
            },
            cursor = {
              inactive_timeout = 0.5,
            },
            misc = {
              disable_hyprland_logo   = true,
              disable_splash_rendering = true,
              background_color        = "rgb(000000)",
            },
          })

          hl.bind(mainMod .. " + Return",    hl.dsp.exec_cmd("anyrun"))
          hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal))
          hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd("brave"))
          hl.bind(mainMod .. " + D",         hl.dsp.window.close())
          hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd("hyprlock"))
          hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("systemctl poweroff"))
          hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
          hl.bind(mainMod .. " + F",         hl.dsp.exec_cmd("ghostty -e yazi $HOME"))
          hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("nemo"))
          hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("${activateObsidian}"))
          hl.bind(mainMod .. " + 0",         hl.dsp.exec_cmd("ghostty --title=grimoire-inbox -e nvim $HOME/Grimoire/Inbox.md"))
          hl.bind(mainMod .. " + Z",         hl.dsp.exec_cmd("${vimEdit}"))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left"  }))
          hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down"  }))
          hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up"    }))
          hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))

          hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left"  }))
          hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down"  }))
          hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up"    }))
          hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

          for i = 1, 9 do
            hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
            hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
          end

          hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"))
          hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
          hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

          hl.bind("Print",            hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
          hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

          hl.bind(mainMod .. " + M",          hl.dsp.layout("colresize +conf"))

          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        '';

        ".config/hypr/hyprlock.conf".text = ''
          background {
            color       = rgba(00ffffee)
            blur_passes = 3
            blur_size   = 7
          }

          input-field {
            size             = 300, 50
            position         = 0, -100
            halign           = center
            valign           = center
            placeholder_text = Password
            dots_center      = true
          }
        '';

        ".config/hypr/hypridle.conf".text = ''
          general {
            lock_cmd         = hyprlock
            before_sleep_cmd = hyprlock
            after_sleep_cmd  = hyprctl dispatch dpms on
          }

          listener {
            timeout    = 600
            on-timeout = bash -c '[ "$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1)" = "0" ] && systemctl suspend'
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
              color: Qt.rgba(0.04, 0.04, 0.08, 0.92)

              PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }
              Process { id: pavuProcess; command: ["${pkgs.pavucontrol}/bin/pavucontrol"] }

              Rectangle {
                  anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                  height: 1
                  color: Qt.rgba(0, 1, 1, 0.3)
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
                                  ? "#00ffff" : "transparent"

                              Text {
                                  anchors.centerIn: parent
                                  text: wsBtn.modelData.id
                                  color: wsBtn.modelData === Hyprland.focusedWorkspace
                                      ? "#0a0a14" : "#555555"
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
                      color: "#cdd6f4"
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
                              color: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "#555555" : "#cdd6f4"
                              text: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "󰸈" :
                                    (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 0.66 ? "󰕾" :
                                    (Pipewire.defaultAudioSink?.audio.volume ?? 0) > 0.33 ? "󰖀" : "󰕿"
                          }

                          Text {
                              anchors.verticalCenter: parent.verticalCenter
                              font.pixelSize: 12
                              font.family: "JetBrains Mono"
                              color: (Pipewire.defaultAudioSink?.audio.muted ?? false) ? "#555555" : "#cdd6f4"
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
                              && UPower.displayDevice.percentage <= 0.20) ? "#ff5555" : "#cdd6f4"
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
                              && UPower.displayDevice.percentage <= 0.20) ? "#ff5555" : "#cdd6f4"
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
                              color: Qt.rgba(0.04, 0.04, 0.08, 0.95)
                              border.color: "#00ffff"
                              border.width: 1
                              radius: 8

                              ColumnLayout {
                                  id: notifInner
                                  anchors { fill: parent; margins: 10 }
                                  spacing: 4

                                  Text {
                                      text: notif.modelData.summary
                                      color: "#cdd6f4"
                                      font.pixelSize: 13
                                      font.family: "JetBrains Mono"
                                      font.bold: true
                                      Layout.fillWidth: true
                                      elide: Text.ElideRight
                                  }

                                  Text {
                                      text: notif.modelData.body
                                      color: "#999999"
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

        ".config/anyrun/config.ron".text = ''
          Config(
              x: Fraction(0.5),
              y: Fraction(0.3),
              width: Absolute(800),
              hide_icons: false,
              ignore_exclusive_zones: false,
              layer: Overlay,
              hide_plugin_info: true,
              close_on_click: false,
              show_results_immediately: false,
              max_entries: Some(8),
              plugins: [
                  "${pkgs.anyrun}/lib/libapplications.so",
                  "${pkgs.anyrun}/lib/librink.so",
                  "${pkgs.anyrun}/lib/libshell.so",
              ],
          )
        '';
      };
    };
  };
}
