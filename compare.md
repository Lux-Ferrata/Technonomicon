# omarchy-nix → Technonomicon Feature Comparison

**Source:** https://github.com/henrysipp/omarchy-nix  
**Purpose:** Selection menu for importing features from omarchy-nix into this config.  
**How to use:** Check `[ ]` boxes for features you want to import. Status tags explain the interaction.

**Status tags:**
- `ALREADY PRESENT` — equivalent or better feature already in Technonomicon
- `NEW` — not in Technonomicon at all; clean addition
- `CONFLICT` — directly conflicts with existing setup (both can't coexist as-is)
- `PARTIAL` — overlapping functionality, different implementation
- `SKIP` — not applicable to this hardware/setup

---

## `flake.nix` — Flake inputs

omarchy-nix uses four inputs: `nixpkgs` (unstable), `hyprland` (flake from hyprwm/Hyprland), `nix-colors`, and `home-manager`.

| Line / Feature | omarchy-nix value | Technonomicon equivalent | Status | Import? |
|---|---|---|---|---|
| `nixpkgs.url` | `nixos-unstable` | `nixos-unstable` (same) | ALREADY PRESENT | — |
| `hyprland` input | `github:hyprwm/Hyprland` — bleeding-edge flake | Uses nixpkgs `programs.hyprland` (stable release) | PARTIAL | `[ ]` |
| `nix-colors` input | `github:misterio77/nix-colors` — base16 color scheme library | Not present; colors are hardcoded Nord | NEW | `[ ]` |
| `home-manager` input | standard HM | Already present | ALREADY PRESENT | — |

**Notes on `hyprland` flake input:** The upstream flake gives the very latest Hyprland commits. Technonomicon currently tracks nixpkgs stable Hyprland. Importing the flake input enables features from the latest releases but may break compatibility. You'd also need to update the `portalPackage` to use `xdg-desktop-portal-hyprland` from nixpkgs (as omarchy does) to avoid Qt version mismatches. This is a prerequisite for several other omarchy features.

**Notes on `nix-colors`:** This is the biggest architectural feature. It provides a base16 palette that flows into every app's theme (ghostty, waybar, btop, wofi, mako, hyprlock, hyprland borders). Without it, individual theming options in omarchy become inert. Adding it would require: (1) add `nix-colors.homeManagerModules.default` to HM imports, (2) set `colorScheme` in HM config.

---

## `config.nix` — Central configuration options

omarchy-nix defines a NixOS module option namespace `omarchy.*` for top-level user-configurable settings. Technonomicon has no equivalent central config system — settings are scattered per-module.

| Option | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `omarchy.full_name` | User's full name (string) | Hardcoded `"xin"` in shell.nix git config | NEW (pattern) | `[ ]` |
| `omarchy.email_address` | User's email (string) | Hardcoded `"git@ironshark.org"` in shell.nix | NEW (pattern) | `[ ]` |
| `omarchy.theme` | Enum: tokyo-night, kanagawa, everforest, catppuccin, nord, gruvbox, gruvbox-light, generated_light, generated_dark; default tokyo-night | No theme system; Nord hardcoded everywhere | NEW | `[ ]` |
| `omarchy.theme_overrides.wallpaper_path` | Path to custom wallpaper; null by default | No wallpaper at all | NEW | `[ ]` |
| `omarchy.primary_font` | String; default `"Liberation Sans 11"` | Fonts set per-app; Iosevka, JetBrains Mono, etc. | PARTIAL | `[ ]` |
| `omarchy.vscode_settings` | Attrs passed to VS Code user settings | VSCodium settings hardcoded in neovim.nix | PARTIAL | `[ ]` |
| `omarchy.monitors` | List of Hyprland monitor strings | Single monitor rule `output=""` auto in hyprland.lua | PARTIAL | `[ ]` |
| `omarchy.scale` | Int display scale factor (1 or 2); default 2 | `xwayland.force_zero_scaling = true`, no scale option | NEW | `[ ]` |
| `omarchy.quick_app_bindings` | List of Hyprland bind strings for app shortcuts; default includes ChatGPT, calendar, email, YouTube, WhatsApp, X | Hardcoded keybindings in hyprland.lua | PARTIAL | `[ ]` |
| `omarchy.exclude_packages` | List of packages to subtract from discretionary package list | No package exclusion mechanism | NEW (pattern) | `[ ]` |

**Note:** The entire `config.nix` options system is an architectural pattern. You could adopt it as a way to centralize per-machine config rather than importing it wholesale. The most useful individual options are `theme`, `scale`, and `monitors`.

---

## `modules/themes.nix` — Theme → base16/VSCode mapping

Maps human-readable theme names to `nix-colors` base16 scheme names and VS Code extension theme names.

| Theme name | base16 scheme | VS Code theme | Status | Import? |
|---|---|---|---|---|
| `tokyo-night` | `tokyo-night-dark` | `Tokyo Night` | NEW | `[ ]` |
| `catppuccin-macchiato` | (none specified) | `Catppuccin Macchiato` | NEW | `[ ]` |
| `kanagawa` | `kanagawa` | `Kanagawa` | NEW | `[ ]` |
| `everforest` | `everforest` | `Everforest Dark` | NEW | `[ ]` |
| `nord` | `nord` | `Nord` | ALREADY PRESENT (Nord already used everywhere) | `[ ]` |
| `gruvbox` | `gruvbox-dark-hard` | `Gruvbox Dark Hard` | NEW | `[ ]` |
| `gruvbox-light` | `gruvbox-light-medium` | `Gruvbox Light Medium` | NEW | `[ ]` |
| `custom` | (dynamic generation) | `Tokyo Night` fallback | NEW | `[ ]` |

**Note:** Importing this file only matters if you also adopt the `nix-colors` input and the `omarchy.theme` option.

---

## `lib/selected-wallpaper.nix` — Wallpaper resolution

Resolves `config.omarchy.theme` and `config.omarchy.theme_overrides.wallpaper_path` to an absolute wallpaper file path. Returns `wallpaper_path` for use by `hyprpaper.nix` and `hyprlock.nix`.

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| Theme → wallpaper filename map | tokyo-night, kanagawa, everforest, nord, gruvbox, gruvbox-light each map to a bundled image | No wallpaper system | NEW | `[ ]` |
| Custom wallpaper override | If `theme_overrides.wallpaper_path` is set, use that instead | — | NEW | `[ ]` |
| Generated-theme wallpaper | Uses `wallpaper_path` as source for color generation | — | NEW | `[ ]` |
| Bundled wallpaper images | 5 images in `config/themes/wallpapers/` (jpg/png) — abstract purple/blue, everforest, gruvbox, kanagawa, nord | None bundled | NEW | `[ ]` |

---

## `modules/packages.nix` — Package tiers

Packages are split into three tiers: `hyprlandPackages` (essential, never excluded), `systemPackages` (essential), `discretionaryPackages` (user can subtract via `exclude_packages`).

### Hyprland essentials (non-excludable)

| Package | Purpose | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `hyprshot` | Region/window/output screenshot tool; replaces grim+slurp pipeline | Has `grim` + `slurp` (manual pipeline) | CONFLICT | `[ ]` |
| `hyprpicker` | Color picker under cursor, copies to clipboard | Has `wl-color-picker` (art.nix) | PARTIAL | `[ ]` |
| `hyprsunset` | Blue light filter (reduces blue light at night) | Not present | NEW | `[ ]` |
| `brightnessctl` | Backlight brightness control | Already present in desktop.nix | ALREADY PRESENT | — |
| `pamixer` | PipeWire/PulseAudio volume CLI (used in media keybinds) | Uses `wpctl` instead | PARTIAL | `[ ]` |
| `playerctl` | MPRIS media player control (play/pause/next/prev) | Not present | NEW | `[ ]` |
| `gnome-themes-extra` | GTK Adwaita themes | Already present in desktop.nix | ALREADY PRESENT | — |
| `pavucontrol` | GUI audio mixer | Already present in desktop.nix | ALREADY PRESENT | — |

### System essentials (non-excludable)

| Package | Purpose | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `git` | Version control | Already present (gitFull in shell.nix) | ALREADY PRESENT | — |
| `vim` | Basic text editor | Not explicitly installed (nvim is primary) | NEW | `[ ]` |
| `libnotify` | `notify-send` for desktop notifications | Used in shell scripts; not explicitly in packages | NEW | `[ ]` |
| `nautilus` | GNOME Files file manager | Has `nemo-with-extensions` (shell.nix) | CONFLICT | `[ ]` |
| `alejandra` | Nix formatter (opinionated) | Has `nixfmt` | CONFLICT | `[ ]` |
| `blueberry` | Bluetooth GUI manager | Has `blueman` (desktop.nix) | CONFLICT | `[ ]` |
| `clipse` | TUI clipboard manager with history, persists clipboard after app close | Has `copyq` (hyprland.nix) | CONFLICT | `[ ]` |
| `fzf` | Fuzzy finder | Present via xonsh config (`xontrib-fzf-widgets`) | ALREADY PRESENT | — |
| `zoxide` | Smart directory jumper | Present in shell.nix | ALREADY PRESENT | — |
| `ripgrep` | Fast text search | Present in shell.nix | ALREADY PRESENT | — |
| `eza` | Modern `ls` replacement | Present in shell.nix | ALREADY PRESENT | — |
| `fd` | Fast `find` replacement | Present in shell.nix | ALREADY PRESENT | — |
| `curl` | HTTP client | Present in shell.nix | ALREADY PRESENT | — |
| `unzip` | Archive extraction | Present in shell.nix | ALREADY PRESENT | — |
| `wget` | File downloader | Present in shell.nix | ALREADY PRESENT | — |
| `gnumake` | Build tool | Present in shell.nix | ALREADY PRESENT | — |

### Discretionary packages (user-excludable)

| Package | Purpose | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `lazygit` | TUI git interface | Present in neovim.nix | ALREADY PRESENT | — |
| `lazydocker` | TUI Docker manager | Not present | NEW | `[ ]` |
| `btop` | TUI system monitor | Present in shell.nix | ALREADY PRESENT | — |
| `powertop` | CPU/power usage analyzer (Intel) | Not present | NEW | `[ ]` |
| `fastfetch` | System info display | Present in shell.nix | ALREADY PRESENT | — |
| `chromium` | Web browser | Has Brave (browsers.nix) | CONFLICT | `[ ]` |
| `obsidian` | Knowledge base / note-taking | Present in mind.nix | ALREADY PRESENT | — |
| `vlc` | Media player | Present in art.nix | ALREADY PRESENT | — |
| `signal-desktop` | Encrypted messaging | Not present; Discord used instead | NEW | `[ ]` |
| `github-desktop` | GUI GitHub client | Has `gh` CLI + `lazyjj` | PARTIAL | `[ ]` |
| `gh` | GitHub CLI | Present in shell.nix | ALREADY PRESENT | — |
| `docker-compose` | Multi-container Docker orchestration | Has `docker` but not compose | NEW | `[ ]` |
| `ffmpeg` | Video/audio processing | Present in art.nix | ALREADY PRESENT | — |
| `typora` | Markdown editor with WYSIWYG preview (x86_64 only, unfree) | Not present | NEW | `[ ]` |
| `dropbox` | Cloud file sync (x86_64 only) | Has Syncthing instead | CONFLICT | `[ ]` |
| `spotify` | Music streaming (x86_64 only, unfree) | Not present | NEW | `[ ]` |

---

## `modules/nixos/system.nix` — NixOS system-level config

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `security.rtkit.enable = true` | Real-time kit for audio priority | Not set (PipeWire works without it but rtkit is recommended) | NEW | `[ ]` |
| `services.pipewire.jack.enable = true` | JACK audio support via PipeWire | Only `alsa` + `pulse` enabled in desktop.nix | NEW | `[ ]` |
| `services.pipewire.alsa.enable = true` | ALSA compat | Same in desktop.nix | ALREADY PRESENT | — |
| `services.pipewire.alsa.support32Bit = true` | 32-bit ALSA for Wine/games | Present in desktop.nix | ALREADY PRESENT | — |
| `services.pipewire.pulse.enable = true` | PulseAudio compat | Same | ALREADY PRESENT | — |
| `services.greetd` with `tuigreet --cmd Hyprland` | Minimal tuigreet, just launches Hyprland directly | Richer tuigreet: `--time --asterisks --remember --sessions` | PARTIAL | `[ ]` |
| `services.resolved.enable = true` | systemd-resolved for DNS | Not present; uses NetworkManager DNS + manual nameservers | NEW | `[ ]` |
| `networking.networkmanager.enable = true` | NetworkManager | Same | ALREADY PRESENT | — |
| `networking.networkmanager.wifi.backend` | Not set (defaults to wpa_supplicant) | Set to `iwd` in network.nix | CONFLICT | `[ ]` |
| `hardware.bluetooth.enable = true` | Bluetooth | Same in desktop.nix | ALREADY PRESENT | — |
| `services.blueman.enable = true` | Blueman service (for applet) | Same (blueman started via autostart in hyprland.nix) | ALREADY PRESENT | — |
| `fonts.packages`: `noto-fonts` | Noto font family | Present in desktop.nix | ALREADY PRESENT | — |
| `fonts.packages`: `noto-fonts-color-emoji` | Color emoji font | Not explicitly present | NEW | `[ ]` |
| `fonts.packages`: `nerd-fonts.caskaydia-mono` | CaskaydiaMono Nerd Font (used by omarchy in bar, terminal, lock) | Not present; JetBrains Mono Nerd Font used instead | NEW | `[ ]` |
| `programs.direnv.enable = true` (system-level) | Direnv system-wide | In HM via `programs.direnv` in shell.nix | ALREADY PRESENT | — |

---

## `modules/nixos/hyprland.nix` — Hyprland system package

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.hyprland.enable = true` | Enables Hyprland | Same in hyprland.nix | ALREADY PRESENT | — |
| `programs.hyprland.package` | From `inputs.hyprland` flake | Default nixpkgs package | PARTIAL | `[ ]` |
| `programs.hyprland.portalPackage` | `xdg-desktop-portal-hyprland` from nixpkgs stable (avoids Qt mismatch) | Same (extraPortals in hyprland.nix) | ALREADY PRESENT | — |

---

## `modules/nixos/1password.nix` — 1Password

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs._1password.enable = true` | 1Password CLI | Not present; Bitwarden CLI used | CONFLICT | `[ ]` |
| `programs._1password-gui.enable = true` | 1Password GUI app | Not present; Bitwarden browser extension | CONFLICT | `[ ]` |
| `programs._1password-gui.polkitPolicyOwners = [ "henry" ]` | Polkit permission for GUI | — | SKIP | — |

---

## `modules/nixos/containers.nix` — Container runtime

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `virtualisation.containers.enable = true` | OCI container support | Not explicitly set | NEW | `[ ]` |
| `virtualisation.docker.enable = true` | Docker daemon | Same in virtualization.nix | ALREADY PRESENT | — |
| Podman (commented out) | Alternative container runtime with Docker compat | Not present | NEW | `[ ]` |

---

## `modules/home-manager/default.nix` — HM root module

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `nix-colors.homeManagerModules.default` import | Provides `colorScheme` option and base16 palette | Not present | NEW | `[ ]` |
| `colorScheme = inputs.nix-colors.colorSchemes.${selectedTheme.base16-theme}` | Sets active color scheme from theme name | Not present; colors hardcoded per app | NEW | `[ ]` |
| Generated color scheme via `colorSchemeFromPicture` | Extracts base16 colors from wallpaper image | Not present | NEW | `[ ]` |
| `gtk.theme.name = "Adwaita:dark"` (or `"Adwaita"` for light) | GTK theme tied to light/dark theme selection | Hardcoded `"Adwaita-dark"` in desktop.nix | PARTIAL | `[ ]` |
| `gtk.theme.package = gnome-themes-extra` | GTK theme package | Same in desktop.nix | ALREADY PRESENT | — |
| `programs.neovim.enable = true` | Enables Neovim (bare, no config) | Full LazyVim setup in neovim.nix | ALREADY PRESENT | — |
| `home.file.".local/share/omarchy/bin"` | Copies bundled scripts to `~/.local/share/omarchy/bin` | Scripts deployed to `/etc/scripts/` | PARTIAL | `[ ]` |
| `home.packages = packages.homePackages` | (Empty list in current omarchy) | — | — | — |

---

## `modules/home-manager/hyprland.nix` — HM Hyprland entrypoint

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `wayland.windowManager.hyprland.enable = true` | Enables Hyprland HM module | Technonomicon configures Hyprland via `home.file` (raw config files) | PARTIAL | `[ ]` |
| `wayland.windowManager.hyprland.package` | From `inputs.hyprland` flake | Not set (uses system package) | PARTIAL | `[ ]` |
| `services.hyprpolkitagent.enable = true` | Hyprland's built-in polkit authentication agent | Not present; no polkit agent running | NEW | `[ ]` |

**Note:** Enabling `wayland.windowManager.hyprland` (HM module) is an alternative to writing raw `hyprland.lua` config files. These two approaches are mutually exclusive — you can't run both. Adopting the HM module approach would require rewriting the Hyprland config from Lua to Nix attribute sets.

---

## `modules/home-manager/hyprland/configuration.nix` — App defaults

Variables used in keybindings. Technonomicon hardcodes app names directly in bindings.

| Variable | omarchy-nix default | Technonomicon equivalent | Status | Import? |
|---|---|---|---|---|
| `$terminal = ghostty` | Terminal emulator | `ghostty` (same) | ALREADY PRESENT | — |
| `$browser = chromium --enable-features=UseOzonePlatform --ozone-platform=wayland` | Web browser | `brave` with similar flags | CONFLICT | `[ ]` |
| `$fileManager = nautilus` | GUI file manager | `nemo` | CONFLICT | `[ ]` |
| `$music = spotify` | Music player | Not present | NEW | `[ ]` |
| `$messenger = signal-desktop` | Messaging app | `flatpak run com.discordapp.Discord` | CONFLICT | `[ ]` |
| `$passwordManager = 1password` | Password manager | Not bound to key | CONFLICT | `[ ]` |
| `$webapp = chromium --app=` | Web app launcher pattern | `brave --app=` (same pattern, different browser) | PARTIAL | `[ ]` |
| Monitor config from `cfg.monitors` | Passed in from omarchy options | Single `output="" mode=preferred position=auto scale=auto` | PARTIAL | `[ ]` |

---

## `modules/home-manager/hyprland/autostart.nix` — Startup programs

| exec-once entry | Purpose | Technonomicon equivalent | Status | Import? |
|---|---|---|---|---|
| `hyprsunset` | Blue light filter daemon | Not present | NEW | `[ ]` |
| `systemctl --user start hyprpolkitagent` | Polkit agent for privilege escalation dialogs | Not present | NEW | `[ ]` |
| `wl-clip-persist --clipboard regular` | Keeps clipboard content alive after app closes | Not present | NEW | `[ ]` |
| `clipse -listen` | Background clipboard history daemon | Uses `copyq --start-server` | CONFLICT | `[ ]` |
| `pkill -SIGUSR2 waybar \|\| waybar` | Start/reload waybar status bar | Uses `quickshell` | CONFLICT | `[ ]` |
| (commented) `dropbox-cli start` | Dropbox cloud sync | Uses Syncthing | SKIP | — |

---

## `modules/home-manager/hyprland/bindings.nix` — Keybindings

### Application launcher

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + Space` | `wofi --show drun --sort-order=alphabetical` | `SUPER + Return` → `anyrun` | CONFLICT | `[ ]` |
| `SUPER SHIFT + Space` | `pkill -SIGUSR1 waybar` (toggle waybar visibility) | Not present | NEW | `[ ]` |

### Window management

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + W` | `killactive` | `SUPER + D` → window close | CONFLICT | `[ ]` |
| `SUPER + Backspace` | `killactive` (second binding) | Not present | NEW | `[ ]` |
| `SUPER + J` | `togglesplit` (dwindle layout) | N/A — scrolling layout used | SKIP | — |
| `SUPER + P` | `pseudo` (dwindle pseudotile) | N/A — scrolling layout | SKIP | — |
| `SUPER + V` | `togglefloating` | Not present | NEW | `[ ]` |
| `SUPER SHIFT + Plus` | `fullscreen` | Not present | NEW | `[ ]` |

### Session management

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + Escape` | `hyprlock` | `SUPER + Q` → `hyprlock` | ALREADY PRESENT (different key) | `[ ]` |
| `SUPER SHIFT + Escape` | `exit` (quit Hyprland) | `SUPER SHIFT + E` → exit | ALREADY PRESENT (different key) | `[ ]` |
| `SUPER CTRL + Escape` | `reboot` | `SUPER SHIFT + Q` → poweroff (via clean-power-off.sh) | PARTIAL | `[ ]` |
| `SUPER SHIFT CTRL + Escape` | `systemctl poweroff` | Combined in SUPER+Shift+Q | PARTIAL | `[ ]` |
| `SUPER + K` | `omarchy-show-keybindings` script → wofi | Not present | NEW | `[ ]` |

### Focus movement

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + left` | `movefocus l` | Same | ALREADY PRESENT | — |
| `SUPER + right` | `movefocus r` | Same | ALREADY PRESENT | — |
| `SUPER + up` | `movefocus u` | Same | ALREADY PRESENT | — |
| `SUPER + down` | `movefocus d` | Same | ALREADY PRESENT | — |

### Workspace switching

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + 1` through `SUPER + 9` | Switch to workspace 1–9 | Same | ALREADY PRESENT | — |
| `SUPER + 0` | Switch to workspace 10 | `SUPER + 0` → grimoire inbox (nvim) | CONFLICT | `[ ]` |
| `SUPER + comma` | Switch to previous workspace | Not present | NEW | `[ ]` |
| `SUPER + period` | Switch to next workspace | Not present | NEW | `[ ]` |
| `SUPER SHIFT + 1` through `SUPER SHIFT + 9` | Move window to workspace 1–9 | Same | ALREADY PRESENT | — |
| `SUPER SHIFT + 0` | Move window to workspace 10 | `SUPER SHIFT + 0` → technonomicon README | CONFLICT | `[ ]` |

### Window movement and resizing

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER SHIFT + left` | `swapwindow l` | `SUPER SHIFT + left` → swap | ALREADY PRESENT | — |
| `SUPER SHIFT + right` | `swapwindow r` | `SUPER SHIFT + right` → swap | ALREADY PRESENT | — |
| `SUPER SHIFT + up` | `swapwindow u` | `SUPER SHIFT + up` → swap | ALREADY PRESENT | — |
| `SUPER SHIFT + down` | `swapwindow d` | `SUPER SHIFT + down` → swap | ALREADY PRESENT | — |
| `SUPER + minus` | `resizeactive -100 0` (shrink width) | Not present | NEW | `[ ]` |
| `SUPER + equal` | `resizeactive 100 0` (grow width) | Not present | NEW | `[ ]` |
| `SUPER SHIFT + minus` | `resizeactive 0 -100` (shrink height) | Not present | NEW | `[ ]` |
| `SUPER SHIFT + equal` | `resizeactive 0 100` (grow height) | Not present | NEW | `[ ]` |
| `SUPER + mouse:272` drag | Move window | Same | ALREADY PRESENT | — |
| `SUPER + mouse:273` drag | Resize window | Same | ALREADY PRESENT | — |
| `SUPER + mouse_down/up` scroll | Switch workspace | `SUPER + mouse:274` → scrollshot (different use) | CONFLICT | `[ ]` |

### Screenshots

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `Print` | `hyprshot -m region` (screenshot region → file) | `Print` → `grim -g "$(slurp)" - \| wl-copy` (region → clipboard) | CONFLICT | `[ ]` |
| `SHIFT + Print` | `hyprshot -m window` (screenshot window) | Not present | NEW | `[ ]` |
| `CTRL + Print` | `hyprshot -m output` (screenshot full screen) | Not present | NEW | `[ ]` |
| `SUPER + Print` | `hyprpicker -a` (color picker) | Not present | NEW | `[ ]` |
| `SUPER + Y` | `grim -g "$(slurp)" - \| wl-copy` | Same action (same key!) | ALREADY PRESENT | — |

### Clipboard

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `CTRL SUPER + V` | `ghostty --class clipse -e clipse` (clipboard TUI) | Not present (copyq has its own UI) | NEW | `[ ]` |

### Media and hardware keys

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `XF86AudioRaiseVolume` | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+` | Same (limit 1.5 vs 1.0) | ALREADY PRESENT | — |
| `XF86AudioLowerVolume` | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-` | Same | ALREADY PRESENT | — |
| `XF86AudioMute` | `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle` | Same | ALREADY PRESENT | — |
| `XF86AudioMicMute` | `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle` | Same | ALREADY PRESENT | — |
| `XF86MonBrightnessUp` | `brightnessctl -e4 -n2 set 5%+` | `brightnessctl set 10%+` | ALREADY PRESENT (different step) | `[ ]` |
| `XF86MonBrightnessDown` | `brightnessctl -e4 -n2 set 5%-` | `brightnessctl set 10%-` | ALREADY PRESENT (different step) | `[ ]` |
| `XF86AudioNext` | `playerctl next` | Not present | NEW | `[ ]` |
| `XF86AudioPause` | `playerctl play-pause` | Not present | NEW | `[ ]` |
| `XF86AudioPlay` | `playerctl play-pause` | Not present | NEW | `[ ]` |
| `XF86AudioPrev` | `playerctl previous` | Not present | NEW | `[ ]` |
| `CTRL + F1` | Apple display brightness -5000 | N/A — no Apple display | SKIP | — |
| `CTRL + F2` | Apple display brightness +5000 | N/A | SKIP | — |
| `SHIFT CTRL + F2` | Apple display brightness +60000 (max) | N/A | SKIP | — |

### Special workspace

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + S` | `togglespecialworkspace magic` | `SUPER + S` → `brave` browser | CONFLICT | `[ ]` |
| `SUPER SHIFT + S` | `movetoworkspace special:magic` | `SUPER SHIFT + 0` → technonomicon README | PARTIAL | `[ ]` |

### quick_app_bindings (default list, all configurable)

| Binding | omarchy-nix action | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `SUPER + A` | Open ChatGPT as web app | Not present | NEW | `[ ]` |
| `SUPER SHIFT + A` | Open Grok as web app | Not present | NEW | `[ ]` |
| `SUPER + C` | Open HEY calendar as web app | `SUPER + C` → `qalculate-gtk` | CONFLICT | `[ ]` |
| `SUPER + E` | Open HEY email as web app | Not present | NEW | `[ ]` |
| `SUPER + Y` | Open YouTube as web app | `SUPER + Y` → screenshot to clipboard | CONFLICT | `[ ]` |
| `SUPER SHIFT + G` | Open WhatsApp as web app | Not present | NEW | `[ ]` |
| `SUPER + X` | Open X (Twitter) as web app | Not present | NEW | `[ ]` |
| `SUPER SHIFT + X` | Open X compose tweet as web app | Not present | NEW | `[ ]` |
| `SUPER + Return` | `$terminal` (ghostty) | `SUPER + Return` → `anyrun` | CONFLICT | `[ ]` |
| `SUPER + F` | `$fileManager` (nautilus) | `SUPER + F` → `ghostty -e yazi $HOME` | CONFLICT | `[ ]` |
| `SUPER + B` | `$browser` (chromium) | `SUPER + S` → `brave` | PARTIAL | `[ ]` |
| `SUPER + M` | `$music` (spotify) | Not present | NEW | `[ ]` |
| `SUPER + N` | `$terminal -e nvim` | `SUPER + N` → activate Obsidian | CONFLICT | `[ ]` |
| `SUPER + T` | `$terminal -e btop` | `SUPER + T` → `ghostty` terminal | CONFLICT | `[ ]` |
| `SUPER + D` | `$terminal -e lazydocker` | `SUPER + D` → close window | CONFLICT | `[ ]` |
| `SUPER + G` | `$messenger` (signal) | Not present | NEW | `[ ]` |
| `SUPER + O` | `obsidian -disable-gpu` | `SUPER + N` → activate Obsidian | CONFLICT | `[ ]` |
| `SUPER + slash` | `$passwordManager` (1password) | Not present | NEW | `[ ]` |

---

## `modules/home-manager/hyprland/envs.nix` — Environment variables

| Variable | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `NVD_BACKEND,direct` | Nvidia backend (conditional on nvidia driver) | Set unconditionally in Akmon host | ALREADY PRESENT (Akmon only) | — |
| `LIBVA_DRIVER_NAME,nvidia` | VAAPI Nvidia (conditional) | Set in Akmon host | ALREADY PRESENT (Akmon only) | — |
| `__GLX_VENDOR_LIBRARY_NAME,nvidia` | GLX Nvidia (conditional) | Set in Akmon host | ALREADY PRESENT (Akmon only) | — |
| `GDK_SCALE,${cfg.scale}` | Display scale from config option | Not set (uses `QT_SCALE_FACTOR=1`, `GDK_SCALE=1`) | PARTIAL | `[ ]` |
| `XCURSOR_SIZE,24` | Cursor size | Set in hyprland.lua (`hl.env`) | ALREADY PRESENT | — |
| `XCURSOR_THEME,Adwaita` | Cursor theme (Adwaita) | `Bibata-Modern-Classic` used in Technonomicon | CONFLICT | `[ ]` |
| `HYPRCURSOR_SIZE,24` | Hyprland cursor size | Set in hyprland.lua | ALREADY PRESENT | — |
| `HYPRCURSOR_THEME,Adwaita` | Hyprland cursor theme (Adwaita) | `Bibata-Modern-Classic` | CONFLICT | `[ ]` |
| `GDK_BACKEND,wayland` | Force GTK to Wayland | `GDK_BACKEND=wayland,x11` in desktop.nix (with X11 fallback) | PARTIAL | `[ ]` |
| `QT_QPA_PLATFORM,wayland` | Force Qt to Wayland | Same in desktop.nix | ALREADY PRESENT | — |
| `QT_STYLE_OVERRIDE,kvantum` | Use Kvantum Qt style | Not set | NEW | `[ ]` |
| `SDL_VIDEODRIVER,wayland` | Force SDL to Wayland | Not set | NEW | `[ ]` |
| `MOZ_ENABLE_WAYLAND,1` | Firefox Wayland backend | Not set | NEW | `[ ]` |
| `ELECTRON_OZONE_PLATFORM_HINT,wayland` | Electron Wayland hint | Same in desktop.nix | ALREADY PRESENT | — |
| `OZONE_PLATFORM,wayland` | Chrome/Electron Ozone | `NIXOS_OZONE_WL=1` achieves same | ALREADY PRESENT | — |
| `CHROMIUM_FLAGS,...` | Chromium Wayland + GTK4 flags | Inline in brave package commandLineArgs | ALREADY PRESENT (Brave) | — |
| `XDG_DATA_DIRS,$XDG_DATA_DIRS:$HOME/.nix-profile/share:...` | Extend XDG data path for .desktop files | Not set; Nix handles this via wrappers | NEW | `[ ]` |
| `XCOMPOSEFILE,~/.XCompose` | XCompose input sequences file | Not set | NEW | `[ ]` |
| `EDITOR,nvim` | Default text editor | Not set as env var (nvim is primary but not exported) | NEW | `[ ]` |
| `GTK_THEME,Adwaita:dark` (or light) | GTK theme env var | Set via dconf in desktop.nix | PARTIAL | `[ ]` |
| `xwayland.force_zero_scaling = true` | XWayland scaling override | Set in hyprland.lua | ALREADY PRESENT | — |
| `ecosystem.no_update_news = true` | Disable Hyprland update popup | Not set | NEW | `[ ]` |

---

## `modules/home-manager/hyprland/input.nix` — Input settings

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `kb_layout = "us"` | US keyboard layout | Same (kanata handles actual layout on top) | ALREADY PRESENT | — |
| `kb_options = "compose:caps"` | Caps Lock becomes Compose key | Technonomicon uses kanata for all key remapping; Caps Lock is part of kanata config | CONFLICT | `[ ]` |
| `follow_mouse = 1` | Focus follows mouse (not click-to-focus) | `follow_mouse = 0` in hyprland.lua (click to focus) | CONFLICT | `[ ]` |
| `sensitivity = 0` | Mouse sensitivity unchanged | Not set explicitly | NEW | `[ ]` |
| `touchpad.natural_scroll = false` | Disable natural scroll | `natural_scroll = true` in hyprland.lua | CONFLICT | `[ ]` |
| `touchpad.disable_while_typing = true` | (implicit default) | `disable_while_typing = true` in hyprland.lua | ALREADY PRESENT | — |
| `gestures.workspace_swipe = false` | Disable touchpad swipe for workspaces | Not set | NEW | `[ ]` |

---

## `modules/home-manager/hyprland/looknfeel.nix` — Visual appearance

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `hexToRgba` helper function | Converts base16 palette hex → `rgba(r,g,b,a)` string | Not needed (uses `rgba(...)` literals) | NEW (if adopting nix-colors) | `[ ]` |
| `general.col.active_border` | From `palette.base0D` + `palette.base0E` gradient | Hardcoded `rgba(00ffffee)` cyan | PARTIAL | `[ ]` |
| `general.col.inactive_border` | From `palette.base03` | Hardcoded `rgba(595959aa)` gray | PARTIAL | `[ ]` |
| `general.gaps_in = 5` | Inner window gap | Same (5) | ALREADY PRESENT | — |
| `general.gaps_out = 10` | Outer window gap | 0 (no outer gap) | PARTIAL | `[ ]` |
| `general.border_size = 2` | Border thickness | Same (2) | ALREADY PRESENT | — |
| `general.layout = "dwindle"` | Tiling layout algorithm | `"scrolling"` in Technonomicon | CONFLICT | `[ ]` |
| `decoration.rounding = 4` | Corner rounding in pixels | 8 in Technonomicon | PARTIAL | `[ ]` |
| `decoration.blur.enabled = true` | Window blur | Not set (blur not configured) | NEW | `[ ]` |
| `decoration.blur.size = 5` | Blur kernel size | — | NEW | `[ ]` |
| `decoration.blur.passes = 2` | Blur quality passes | — | NEW | `[ ]` |
| `decoration.shadow.enabled = false` | No window shadows | Not set | NEW | `[ ]` |
| `misc.disable_hyprland_logo = true` | No logo on empty desktop | Same in hyprland.lua | ALREADY PRESENT | — |
| `misc.disable_splash_rendering = true` | No splash screen | Same | ALREADY PRESENT | — |
| `bezierCurve "easeOutQuint"` | `0.23, 1, 0.32, 1` | No custom bezier curves | NEW | `[ ]` |
| `bezierCurve "easeInOutCubic"` | `0.65, 0.05, 0.35, 0.95` | — | NEW | `[ ]` |
| `bezierCurve "linear"` | `0, 0, 1, 1` | — | NEW | `[ ]` |
| `bezierCurve "almostLinear"` | `0.5, 0.5, 0.75, 1.0` | — | NEW | `[ ]` |
| `bezierCurve "quick"` | `0.15, 0, 0.1, 1` | — | NEW | `[ ]` |
| `animation "global"` | `global, 1, 10, default` | No animations configured | NEW | `[ ]` |
| `animation "border"` | `border, 1, 5.39, easeOutQuint` | — | NEW | `[ ]` |
| `animation "windows"` | `windows, 1, 4.79, easeOutQuint` | — | NEW | `[ ]` |
| `animation "windowsIn"` | `windowsIn, 1, 4.1, easeOutQuint, popin 87%` | — | NEW | `[ ]` |
| `animation "windowsOut"` | `windowsOut, 1, 1.49, linear, popin 87%` | — | NEW | `[ ]` |
| `animation "fadeIn"` | `fadeIn, 1, 1.73, almostLinear` | — | NEW | `[ ]` |
| `animation "fadeOut"` | `fadeOut, 1, 1.46, almostLinear` | — | NEW | `[ ]` |
| `animation "fade"` | `fade, 1, 3.03, quick` | — | NEW | `[ ]` |
| `animation "layers"` | `layers, 1, 3.81, easeOutQuint` | — | NEW | `[ ]` |
| `animation "layersIn"` | `layersIn, 1, 4, easeOutQuint, fade` | — | NEW | `[ ]` |
| `animation "layersOut"` | `layersOut, 1, 1.5, linear, fade` | — | NEW | `[ ]` |
| `animation "fadeLayersIn"` | `fadeLayersIn, 1, 1.79, almostLinear` | — | NEW | `[ ]` |
| `animation "fadeLayersOut"` | `fadeLayersOut, 1, 1.39, almostLinear` | — | NEW | `[ ]` |
| `animation "workspaces"` | `workspaces, 1, 1.94, almostLinear, fade` | — | NEW | `[ ]` |
| `animation "workspacesIn"` | `workspacesIn, 1, 1.21, almostLinear, fade` | — | NEW | `[ ]` |
| `animation "workspacesOut"` | `workspacesOut, 1, 1.94, almostLinear, fade` | — | NEW | `[ ]` |
| `dwindle.pseudotile = true` | Pseudotile mode (dwindle only) | N/A — scrolling layout | SKIP | — |
| `dwindle.preserve_split = true` | Preserve split direction (dwindle only) | N/A | SKIP | — |
| `master.new_status = "master"` | New windows become master (master layout) | N/A | SKIP | — |

---

## `modules/home-manager/hyprland/windows.nix` — Window rules

| Rule | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `suppressevent maximize, class:.*` | Prevent all windows from requesting maximize | Not present | NEW | `[ ]` |
| `tile, class:^(chromium)$` | Force Chromium to tile (workaround for `--app` mode) | Not needed (Brave doesn't have this bug) | SKIP | — |
| `float, class:^(org.pulseaudio.pavucontrol\|blueberry.py)$` | Float audio and bluetooth settings | Has `portal-dialog-size` float rule; no pavucontrol float rule | NEW | `[ ]` |
| `float, class:^(steam)$` | Float Steam main window | Not present | NEW | `[ ]` |
| `fullscreen, class:^(com.libretro.RetroArch)$` | Fullscreen RetroArch | Not present | NEW | `[ ]` |
| `opacity 0.97 0.9, class:.*` | Global default opacity (active/inactive) | Not present | NEW | `[ ]` |
| `opacity 1 1, class:^(chromium\|google-chrome.*)$, title:.*Youtube.*` | Full opacity for YouTube tabs | Not present | NEW | `[ ]` |
| `opacity 1 0.97, class:^(chromium\|google-chrome.*)$` | Chromium slightly transparent when inactive | Not present | NEW | `[ ]` |
| `opacity 0.97 0.9, initialClass:^(chrome-.*-Default)$` | Web app opacity | Not present | NEW | `[ ]` |
| `opacity 1 1, initialClass:^(chrome-youtube.*-Default)$` | YouTube web app full opacity | Not present | NEW | `[ ]` |
| `opacity 1 1, class:^(zoom\|vlc\|org.kde.kdenlive\|com.obsproject.Studio)$` | Full opacity for media/video | Not present | NEW | `[ ]` |
| `opacity 1 1, class:^(com.libretro.RetroArch\|steam)$` | Full opacity for games | Not present | NEW | `[ ]` |
| `nofocus,class:^$,title:^$,xwayland:1,floating:1,...` | Fix XWayland drag issues | Not present | NEW | `[ ]` |
| `float, class:(clipse)` | Float clipse clipboard window | Not present (copyq used) | CONFLICT | `[ ]` |
| `size 622 652, class:(clipse)` | Clipse window size | Not present | CONFLICT | `[ ]` |
| `stayfocused, class:(clipse)` | Keep clipse focused | Not present | CONFLICT | `[ ]` |
| `layerrule blur,wofi` | Blur wofi background | N/A (anyrun used) | CONFLICT | `[ ]` |
| `layerrule blur,waybar` | Blur waybar | N/A (quickshell used) | CONFLICT | `[ ]` |

---

## `modules/home-manager/ghostty.nix` — Terminal emulator

Technonomicon sets ghostty config via `home.file.".config/ghostty/config"` in neovim.nix.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `window-padding-x = 14` | 14px horizontal padding | Not set (default 0) | NEW | `[ ]` |
| `window-padding-y = 14` | 14px vertical padding | Not set | NEW | `[ ]` |
| `background-opacity = 0.95` | 5% transparent background | Not set (fully opaque) | NEW | `[ ]` |
| `window-decoration = "none"` | No window title bar | Not set | NEW | `[ ]` |
| `font-family = cfg.primary_font` | Font from omarchy config option | Not set (system monospace) | NEW | `[ ]` |
| `font-size = 12` | Font size | Not set | NEW | `[ ]` |
| `theme = "omarchy"` | Custom theme from base16 palette | Not set (no theme configured) | NEW (requires nix-colors) | `[ ]` |
| `keybind = ["ctrl+k=reset"]` | Ctrl+K clears terminal | Not set | NEW | `[ ]` |
| `command = zellij` | Auto-launch zellij | Technonomicon has `command = zellij` | ALREADY PRESENT | — |
| `confirm-close-surface = false` | No close confirmation | Technonomicon has this | ALREADY PRESENT | — |

**Note:** The `theme = "omarchy"` block maps all 22 base16 palette colors to terminal colors. This is only useful if you adopt `nix-colors`.

---

## `modules/home-manager/hyprlock.nix` — Lock screen

Technonomicon sets hyprlock config via `home.file.".config/hypr/hyprlock.conf"` in hyprland.nix.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `general.disable_loading_bar = true` | No loading bar | Not set | NEW | `[ ]` |
| `general.no_fade_in = false` | Fade in on lock | Not set | NEW | `[ ]` |
| `auth.fingerprint.enabled = true` | Fingerprint unlock support | Not present | NEW | `[ ]` |
| `background.path = selected_wallpaper_path` | Uses theme wallpaper as background | `background.color = rgba(00ffffee)` (solid cyan) | CONFLICT | `[ ]` |
| `input-field.size = "600, 100"` | Large input field | `size = 300, 50` | PARTIAL | `[ ]` |
| `input-field.position = "0, 0"` | Centered | `position = 0, -100` (slightly below center) | PARTIAL | `[ ]` |
| `input-field.inner_color` | From `palette.base02` | Not set | NEW | `[ ]` |
| `input-field.outer_color` | From `palette.base05` | Not set | NEW | `[ ]` |
| `input-field.outline_thickness = 4` | Border thickness | Not set | NEW | `[ ]` |
| `input-field.font_family = "CaskaydiaMono Nerd Font"` | Font | Not set | NEW | `[ ]` |
| `input-field.font_size = 32` | Large font | Not set | NEW | `[ ]` |
| `input-field.font_color` | From palette | Not set | NEW | `[ ]` |
| `input-field.placeholder_text = "  Enter Password 󰈷 "` | Custom placeholder with icons | `placeholder_text = Password` | PARTIAL | `[ ]` |
| `input-field.rounding = 0` | Square input field | Not set | NEW | `[ ]` |
| `input-field.fade_on_empty = false` | Don't fade out when empty | Not set | NEW | `[ ]` |
| `label` for `$FPRINTPROMPT` | Shows fingerprint prompt text | Not present | NEW | `[ ]` |

---

## `modules/home-manager/hyprpaper.nix` — Wallpaper daemon

Technonomicon has no wallpaper; `misc.background_color = "rgb(000000)"` (solid black).

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `home.file."Pictures/Wallpapers"` | Copies bundled wallpapers to ~/Pictures/Wallpapers | Not present | NEW | `[ ]` |
| `services.hyprpaper.enable = true` | Enables hyprpaper wallpaper daemon | Not present | NEW | `[ ]` |
| `services.hyprpaper.settings.preload` | Preloads selected wallpaper path | Not present | NEW | `[ ]` |
| `services.hyprpaper.settings.wallpaper` | Sets wallpaper per-monitor | Not present | NEW | `[ ]` |

**Note:** If you want wallpaper without the full omarchy theme system, you can use `services.hyprpaper` directly with a hardcoded path and skip `lib/selected-wallpaper.nix`.

---

## `modules/home-manager/hypridle.nix` — Idle management

Technonomicon sets hypridle config via `home.file.".config/hypr/hypridle.conf"` in hyprland.nix.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `general.lock_cmd = "pidof hyprlock \|\| hyprlock"` | Prevent duplicate lock instances | `lock_cmd = hyprlock` (could spawn duplicates) | NEW | `[ ]` |
| `general.before_sleep_cmd = "loginctl lock-session"` | Lock via loginctl on sleep | `before_sleep_cmd = hyprlock` (direct) | PARTIAL | `[ ]` |
| `general.after_sleep_cmd = "hyprctl dispatch dpms on"` | Turn display on after wake | Same in Technonomicon | ALREADY PRESENT | — |
| `listener[0].timeout = 300` | Lock after 5 minutes idle | 600 seconds (10 minutes) and only on battery | PARTIAL | `[ ]` |
| `listener[0].on-timeout = "loginctl lock-session"` | Trigger lock | `lock_cmd = hyprlock` | PARTIAL | `[ ]` |
| `listener[1].timeout = 330` | Turn display off at 5:30 | No display-off listener in Technonomicon | NEW | `[ ]` |
| `listener[1].on-timeout = "hyprctl dispatch dpms off"` | DPMS off | Not present | NEW | `[ ]` |
| `listener[1].on-resume = "hyprctl dispatch dpms on && brightnessctl -r"` | Restore display and brightness | Technonomicon: `after_sleep_cmd = hyprctl dispatch dpms on` (no brightnessctl) | NEW | `[ ]` |

---

## `modules/home-manager/mako.nix` — Notification daemon

Technonomicon uses `quickshell` with a custom QML `Notifications.qml` component instead of a dedicated notification daemon.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `services.mako.enable = true` | Mako notification daemon | Quickshell `NotificationServer` | CONFLICT | `[ ]` |
| `settings.background-color` | From `palette.base00` | Hardcoded `rgba(0.04, 0.04, 0.08, 0.95)` | CONFLICT | `[ ]` |
| `settings.text-color` | From `palette.base05` | Hardcoded `#cdd6f4` | CONFLICT | `[ ]` |
| `settings.border-color` | From `palette.base04` | Hardcoded `#00ffff` (cyan) | CONFLICT | `[ ]` |
| `settings.progress-color` | From `palette.base0D` | Not set | NEW | `[ ]` |
| `settings.width = 420` | Notification width | 360px in quickshell | PARTIAL | `[ ]` |
| `settings.height = 110` | Max notification height | Implicit in quickshell layout | PARTIAL | `[ ]` |
| `settings.padding = "10"` | Inner padding | 10px margins in quickshell | PARTIAL | `[ ]` |
| `settings.margin = "10"` | Outer margin | `margins.top: 44; margins.right: 8` | PARTIAL | `[ ]` |
| `settings.border-size = 2` | Border width | 1px in quickshell | PARTIAL | `[ ]` |
| `settings.border-radius = 0` | Square corners | `radius: 8` in quickshell | CONFLICT | `[ ]` |
| `settings.anchor = "top-right"` | Position | `anchors { top: true; right: true }` (same) | ALREADY PRESENT | — |
| `settings.default-timeout = 5000` | 5 second auto-dismiss | Timer in quickshell (3000ms default, or `expireTimeout`) | PARTIAL | `[ ]` |
| `settings.max-visible = 5` | Show up to 5 notifications | Unlimited in quickshell (all `trackedNotifications`) | PARTIAL | `[ ]` |
| `settings.sort = "-time"` | Newest first | Quickshell uses list order | PARTIAL | `[ ]` |
| `settings.group-by = "app-name"` | Group notifications by app | Not implemented in quickshell | NEW | `[ ]` |
| `settings.format = "<b>%s</b>\\n%b"` | Bold summary + body | Separate Text elements in quickshell | ALREADY PRESENT | — |
| `settings.markup = true` | Allow HTML markup in notifications | Not set in quickshell | NEW | `[ ]` |

---

## `config/waybar/style.css` + `modules/home-manager/waybar.nix` — Status bar

Technonomicon uses `quickshell` with custom QML for the status bar. Waybar is a separate program.

**These two are mutually exclusive — choose one bar.**

### waybar.nix — Bar configuration

| Feature | omarchy-nix | Technonomicon (quickshell) | Status | Import? |
|---|---|---|---|---|
| Bar position: top | Top of screen | Top (same) | ALREADY PRESENT | — |
| Bar height: 26px | 26px | 36px | PARTIAL | `[ ]` |
| Background color | From `palette.base00` (via theme.css) | `Qt.rgba(0.04, 0.04, 0.08, 0.92)` hardcoded | PARTIAL | `[ ]` |
| `hyprland/workspaces` module | Clickable workspace dots, persistent 1-5 | Custom QML with cyan highlight for active | ALREADY PRESENT | — |
| Workspace icons | Numeric (1-9), active = `󱓻` | Numeric, active = cyan filled square | PARTIAL | `[ ]` |
| Persistent workspaces 1-5 | Always visible | All workspaces shown | ALREADY PRESENT | — |
| `clock` module | `{:%A %I:%M %p}` (Monday 02:30 PM) | `ddd MMM dd  HH:mm` (Mon Jan 01  14:30) | PARTIAL | `[ ]` |
| Clock alt format | `{:%d %B W%V %Y}` on click | Not present | NEW | `[ ]` |
| `tray` module | System tray | System tray (same) | ALREADY PRESENT | — |
| `bluetooth` module | Bluetooth icon, click → blueberry | Not present in quickshell bar | NEW | `[ ]` |
| `network` module | WiFi/ethernet icon, tooltip bandwidth | WiFi/ethernet/offline icon, click → notify | PARTIAL | `[ ]` |
| Network on-click | `ghostty -e nmcli` | Runs `/etc/scripts/net-info.sh` notify-send | PARTIAL | `[ ]` |
| `wireplumber` module | Volume icon, scroll to adjust, right-click mute | Custom volume widget with nerd font icons | ALREADY PRESENT | — |
| Volume max | 150% | 150% (same) | ALREADY PRESENT | — |
| `cpu` module | CPU icon, click → `ghostty -e btop` | Not in quickshell bar | NEW | `[ ]` |
| `power-profiles-daemon` module | Power saver/balanced/performance icon | Not present | NEW | `[ ]` |
| `battery` module | Capacity %, charging icons, warnings at 20%/10% | Battery % + icon, red at ≤20% | ALREADY PRESENT | — |
| Battery format icons | 10-icon arrays for charging/discharging | Single icon per state | PARTIAL | `[ ]` |

### style.css

| Style | omarchy-nix | Status | Import? |
|---|---|---|---|
| `font-family: CaskaydiaMono Nerd Font` | Bar font | NEW (requires that font) | `[ ]` |
| `font-size: 14px` | Text size | NEW | `[ ]` |
| Workspace button padding `2px 6px` | Compact buttons | NEW | `[ ]` |
| `@import "./theme.css"` | Dynamic colors from nix-colors | NEW | `[ ]` |
| Right-module `margin-right: 13px` | Spacing between widgets | NEW | `[ ]` |
| `min-width: 12px` | Minimum widget size | NEW | `[ ]` |

---

## `modules/home-manager/wofi.nix` — Application launcher

Technonomicon uses `anyrun` with libapplications, librink (calculator), and libshell plugins.

| Feature | omarchy-nix (wofi) | Technonomicon (anyrun) | Status | Import? |
|---|---|---|---|---|
| Launcher program | `wofi` | `anyrun` | CONFLICT | `[ ]` |
| Dimensions | 600×350px | 800px wide, positioned at 50% x 30% y | PARTIAL | `[ ]` |
| Display mode | `drun` (desktop apps only) | libapplications + librink (math) + libshell (commands) | PARTIAL | `[ ]` |
| Font | CaskaydiaMono Nerd Font 18px | Not configured (system default) | NEW | `[ ]` |
| Window opacity | 0.95 | Not set | NEW | `[ ]` |
| Icon support | 40px images | `hide_icons: false` (default icons) | ALREADY PRESENT | — |
| Case-insensitive | Yes | Not configured | NEW | `[ ]` |
| Markup | Yes | Not set | NEW | `[ ]` |
| Colors | From `palette.base00/05/01/07` | Not configured (system theme) | NEW (requires nix-colors) | `[ ]` |

---

## `modules/home-manager/btop.nix` — System monitor configuration

Technonomicon installs btop in shell.nix but provides zero configuration.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| Custom btop theme file from base16 palette | Dynamic colors mapped from `palette.base0*` | No theme configured | NEW (requires nix-colors) | `[ ]` |
| `color_theme` | Points to generated theme file | Not set | NEW | `[ ]` |
| `rounded_corners = True` | Rounded TUI boxes | Not set | NEW | `[ ]` |
| `graph_symbol = "braille"` | Braille characters for graphs | Not set | NEW | `[ ]` |
| `vim_keys = True` | hjkl navigation | Not set | NEW | `[ ]` |
| `shown_boxes = "cpu mem net proc"` | Show CPU, memory, network, processes | Not set | NEW | `[ ]` |
| `update_ms = 2000` | 2 second refresh | Not set | NEW | `[ ]` |
| `proc_sorting = "cpu lazy"` | Sort processes by CPU | Not set | NEW | `[ ]` |
| `temp_scale = "celsius"` | Temperature in Celsius | Not set | NEW | `[ ]` |
| `draw_clock = ""` | No clock in btop | Not set | NEW | `[ ]` |
| (Theme) Main background: `palette.base00` | Terminal background color | — | NEW | `[ ]` |
| (Theme) Main text: `palette.base05` | Primary text | — | NEW | `[ ]` |
| (Theme) Title text: `palette.base0D` | Blue-ish accent | — | NEW | `[ ]` |
| (Theme) CPU boxes: `palette.base0E` | Magenta accent | — | NEW | `[ ]` |
| (Theme) Memory: `palette.base0B` | Green accent | — | NEW | `[ ]` |
| (Theme) Network: `palette.base0C` | Cyan accent | — | NEW | `[ ]` |
| (Theme) Processes: `palette.base0A` | Yellow accent | — | NEW | `[ ]` |

**Note:** The btop theme (`home.file.".config/btop/themes/omarchy.theme"`) can be adopted independently by hardcoding Nord palette hex values without the nix-colors system.

---

## `modules/home-manager/vscode.nix` — VS Code configuration

Technonomicon uses VSCodium (not VS Code) with Nord theme, configured in neovim.nix.

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.vscode.enable = true` | VS Code (proprietary) | VSCodium (open source) | CONFLICT | `[ ]` |
| Extension: `bbenoist.nix` | Nix syntax highlighting | Not installed in VSCodium | NEW | `[ ]` |
| Extension: `vscodevim.vim` | Vim keybindings | Not installed in VSCodium | NEW | `[ ]` |
| Theme extension: Everforest | Everforest theme | Not present | NEW | `[ ]` |
| Theme extension: Tokyo Night | Tokyo Night theme | Not present | NEW | `[ ]` |
| Theme extension: Kanagawa | Kanagawa theme | Not present | NEW | `[ ]` |
| Theme extension: Nord (vscodevim) | Nord theme | `arcticicestudio.nord-visual-studio-code` in VSCodium | ALREADY PRESENT | — |
| Theme extension: Gruvbox | Gruvbox theme | Not present | NEW | `[ ]` |
| `userSettings` | Commented out (author found it annoying) | Nord theme, JetBrains Mono, relative numbers, no minimap | N/A | — |

---

## `modules/home-manager/git.nix` — Git configuration

Technonomicon configures git in shell.nix with more options than omarchy.

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `userName` | From `cfg.full_name` | Hardcoded `"xin"` | ALREADY PRESENT | — |
| `userEmail` | From `cfg.email_address` | Hardcoded `"git@ironshark.org"` | ALREADY PRESENT | — |
| `extraConfig.credential.helper = "store"` | Store credentials in `~/.git-credentials` (plaintext) | No credential helper (uses SSH keys) | NEW | `[ ]` |
| `programs.gh.enable = true` | GitHub CLI | Present in shell.nix packages | ALREADY PRESENT | — |
| `programs.gh.gitCredentialHelper.enable = true` | gh as git credential helper | Not set | NEW | `[ ]` |
| Git aliases | None | `save`, `send`, `unstage`, `history`, `last` | N/A | — |
| Global gitignore | None | `*~`, `.*~`, `#*#`, `.*.swp` | N/A | — |
| `init.defaultBranch` | Not set | `main` | N/A | — |
| `pull.rebase` | Not set | `false` | N/A | — |

---

## `modules/home-manager/starship.nix` — Shell prompt

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.starship.enable = true` | Enable starship (no config) | Enabled with detailed config (format, colors, git, nix_shell) | ALREADY PRESENT | — |
| No starship `settings` | Default format | Custom format with directory, nix_shell, git info | N/A | — |

---

## `modules/home-manager/direnv.nix` — Directory environments

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.direnv.enable = true` | Enable direnv | Enabled in shell.nix | ALREADY PRESENT | — |
| `programs.direnv.enableZshIntegration = true` | Zsh hook for direnv | Not applicable (xonsh used) | CONFLICT | `[ ]` |
| `programs.direnv.nix-direnv.enable = true` | Nix-aware direnv | Same in shell.nix | ALREADY PRESENT | — |

---

## `modules/home-manager/zoxide.nix` — Smart directory jumping

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.zoxide.enable = true` | Enable zoxide | Present in shell.nix packages + xonsh config | ALREADY PRESENT | — |
| `programs.zoxide.enableZshIntegration = true` | Zsh hook for `z` command | Not applicable (xonsh integration in `_config.xsh`) | CONFLICT | `[ ]` |

---

## `modules/home-manager/fonts.nix` — Font configuration

| Setting | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `fonts.fontconfig.enable = true` | Enable fontconfig | Implicit | ALREADY PRESENT | — |
| `fonts.fontconfig.defaultFonts.serif = ["Noto Serif"]` | System serif font | Not set | NEW | `[ ]` |
| `fonts.fontconfig.defaultFonts.sansSerif = ["Noto Sans"]` | System sans-serif font | Not set | NEW | `[ ]` |
| `fonts.fontconfig.defaultFonts.monospace = ["Caskaydia Mono Nerd Font"]` | System monospace font | Not set (JetBrains Mono installed but not set as default) | NEW | `[ ]` |

---

## `modules/home-manager/zsh.nix` — Shell

Technonomicon uses xonsh, not zsh.

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| `programs.zsh.enable = true` | Enable zsh | xonsh is the primary shell | CONFLICT | `[ ]` |
| `programs.zsh.autosuggestion.enable = true` | Inline command suggestions | xonsh has its own completion | CONFLICT | `[ ]` |
| `programs.zsh.zplug.enable = true` | Plugin manager | N/A | SKIP | — |
| `zplug`: `plugins/git` from oh-my-zsh | Git aliases and functions | git aliases set manually in shell.nix | SKIP | — |
| `zplug`: `fdellwing/zsh-bat` | Replace `cat` with `bat` in zsh | `bat` installed via shell.nix; xonsh uses it directly | SKIP | — |

---

## `bin/omarchy-show-keybindings` — Keybinding viewer script

| Feature | omarchy-nix | Technonomicon | Status | Import? |
|---|---|---|---|---|
| Bash script to parse `~/.config/hypr/hyprland.conf` for bindings | Reads `bind =` and `bind=` lines, extracts modifier+key | Not present | NEW | `[ ]` |
| Handles both `bind =` and `bind=` formats | Regex-based parsing | — | NEW | `[ ]` |
| Displays results in wofi at 50% width / 40% height | Shows filterable list of all keybindings | Not present | NEW | `[ ]` |
| Uses `flock` to prevent multiple instances | Single-instance guarantee | — | NEW | `[ ]` |

**Note:** If you want this, you'd need to adapt it to parse the Lua-based `hyprland.lua` format instead of the INI `hyprland.conf` format. The regex won't work as-is with Technonomicon's Lua config.

---

## Summary: High-value NEW features to consider

The following are non-conflicting additions that would work well with the current setup:

| Feature | File | Effort |
|---|---|---|
| `hyprsunset` blue light filter | packages.nix + autostart | Low |
| `playerctl` media key support | packages.nix + bindings | Low |
| `security.rtkit.enable` | nixos/system.nix | Low |
| `pipewire.jack.enable` | nixos/system.nix | Low |
| `services.resolved.enable` | nixos/system.nix | Low |
| `noto-fonts-color-emoji` | nixos/system.nix | Low |
| `ecosystem.no_update_news` | hyprland config | Low |
| `services.hyprpolkitagent` | home-manager | Low |
| Display-off idle listener (330s) | hypridle | Low |
| `pidof hyprlock \|\|` guard in idle | hypridle | Low |
| Window opacity rules | windows.nix | Low |
| XWayland drag fix | windows.nix | Low |
| Float pavucontrol/blueberry | windows.nix | Low |
| `suppressevent maximize` window rule | windows.nix | Low |
| `lazydocker` | packages.nix | Low |
| `docker-compose` | packages.nix | Low |
| `signal-desktop` | packages.nix | Low |
| `spotify` | packages.nix | Low |
| `typora` | packages.nix | Low |
| `powertop` | packages.nix | Low |
| `btop` config (vim keys, braille, etc.) | btop.nix | Low |
| Ghostty padding + opacity + font | ghostty.nix | Low |
| fontconfig defaults | fonts.nix | Low |
| Hyprland window resize bindings | bindings | Low |
| SUPER+V togglefloating | bindings | Low |
| SUPER+Shift+Plus fullscreen | bindings | Low |
| SUPER+comma/period workspace prev/next | bindings | Low |
| `MOZ_ENABLE_WAYLAND` env var | envs | Low |
| `SDL_VIDEODRIVER=wayland` env var | envs | Low |
| `EDITOR=nvim` env var | envs | Low |
| `XDG_DATA_DIRS` extension | envs | Low |
| `nix-colors` base16 theming system | flake + HM | High |
| `hyprpaper` wallpaper | hyprpaper.nix | Medium |
| `mako` notifications (replace quickshell notifications) | mako.nix | Medium |
| `waybar` (replace quickshell bar) | waybar.nix + style.css | High |
| `wofi` (replace anyrun) | wofi.nix | Medium |
| `clipse` clipboard (replace copyq) | packages + autostart + window rules | Medium |
| Hyprland animations (Bezier curves) | looknfeel | Low |
| Hyprland blur + shadow-off | looknfeel | Low |
| `wl-clip-persist` clipboard persistence | autostart | Low |
