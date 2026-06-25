# Technonomicon — Configuration Reference

Complete reference for every design decision, package, and setting in the Technonomicon NixOS configuration.

---

## 1. Overview & Philosophy

Technonomicon is a personal NixOS flake configuration for two machines:

- **Akmon** — desktop, Intel CPU + Nvidia GPU, Kinesis Advantage2 keyboard
- **Kvasir** — Lenovo ThinkPad T480s laptop

**Migration:** switching from Emacs (Doom) + EWM to Hyprland + Neovim as the primary workflow. The goal is a stable, flexible academic workstation for a college student and researcher in the math/physics/CS fields.

**Design philosophy: single level of depth.** Avoid nested complexity — find everything from the top level. Concretely: Brave with the no-tabs extension instead of tab groups, Harpoon instead of buffer trees, flat Taskwarrior contexts instead of nested projects, flat Obsidian vault instead of nested folders, nvim in a dedicated Hyprland workspace instead of editor-within-editor nesting.

**Key features that define the workflow:**
- Hyprland with a dedicated nvim workspace (SUPER+Space) and a ghostty scratchpad (SUPER+\`) for quick shell utilities
- Neovim via lazyvim-nix with obsidian.nvim for notes and molten for Jupyter
- Taskwarrior + Timewarrior with Habitica integration for habit/task sync
- hypr-dynamic-cursors for cursor hide-on-keypress and shake-to-find
- wl-kbptr in floating mode for keyboard-driven pointer control
- Thunderbird + tbkeys (vim keybindings) + Google Calendar web-app

---

## 2. Flake Architecture

### Inputs (current: 5 active)

| Input | Source | Notes |
|---|---|---|
| `nixpkgs` | `github:nixos/nixpkgs?ref=nixos-unstable` | Primary package channel |
| `flake-parts` | `github:hercules-ci/flake-parts` | Outputs layer framework |
| `import-tree` | `github:vic/import-tree` | Auto-imports every `.nix` file under a directory tree |
| `nixos-hardware` | `github:NixOS/nixos-hardware/master` | ThinkPad T480s preset (Kvasir only) |
| `sops-nix` | `github:Mic92/sops-nix` | Follows nixpkgs |

**To be re-added as features are restored:**

| Input | Source | Notes |
|---|---|---|
| `nixpkgs-stable` | `github:nixos/nixpkgs/nixos-26.05` | Passed as `pkgs-stable` specialArg; stable fallbacks |
| `nix-index-database` | `github:nix-community/nix-index-database` | Follows nixpkgs |
| `home-manager` | `github:nix-community/home-manager` | Follows nixpkgs |
| `hyprland` | `github:hyprwm/Hyprland` | Follows nixpkgs |
| `lazyvim-nix` | `github:pfassina/lazyvim-nix` | Follows nixpkgs |
| `plover-flake` | `github:openstenoproject/plover-flake` | No nixpkgs pin |

### Auto-discovery via import-tree

No central module list anywhere. Three directory trees are auto-imported:

- `./Modules/` → shared NixOS modules, each exposes `flake.nixosModules.Tn-<Name>`
- `./Hosts/` → per-host `nixosConfigurations`
- `./Home/` → home-manager user config (exposes `flake.nixosModules.Home-xin`)

Dropping a `.nix` file into any of these directories registers it automatically. The file is responsible for declaring its own output key.

### Systems

`[ "x86_64-linux" ]` only. Single-arch design.

---

## 3. Module Naming Convention

All shared modules use the `Tn-` prefix (Technonomicon namespace). These are stripped in the current skeleton and will be re-added one feature set at a time.

**Core:** `Tn-nix`, `Tn-desktop`, `Tn-network`, `Tn-shell`, `Tn-sound`, `Tn-utf`, `Tn-virtualization`

**Desktop:** `Tn-hyprland`, `Tn-lock`, `Tn-display-manager`

**Input:** `Tn-kanata`

**Academic:** `Tn-documents`, `Tn-math`, `Tn-references`, `Tn-anki`

**Knowledge:** `Tn-pdf`, `Tn-learning`

**Productivity:** `Tn-tasks`, `Tn-mail`, `Tn-calendar`, `Tn-quantified`, `Tn-backup`

**Web:** `Tn-web-browsers`, `Tn-web-apps`, `Tn-communication`, `Tn-games`

**Art:** `Tn-art`

**Home:** `Home-xin`

---

## 4. Secrets Management

- **Tool:** sops-nix + age encryption
- **Recipients:** three age public keys configured in `.sops.yaml`
- **Decryption key:** SSH host key at `/etc/ssh/ssh_host_ed25519_key`
- **File:** `_secrets.yaml` at repo root, AES256_GCM, SOPS 3.13.0
- **Currently managed:** `xin-password` only (user login hash)
- **To be added:** `google-app-password`, `habitica-api-key`, `habitica-user-id`, `borg-passphrase`
- `users.mutableUsers = false` on both hosts — declarative passwords, no passwd fallback

To edit secrets: `sops _secrets.yaml`

---

## 5. Host Configurations

### Akmon (desktop)

**Hardware:**
- Intel CPU → `boot.kernelModules = ["kvm-intel"]`
- Nvidia GPU: open drivers, stable package, `nvidia-drm.modeset=1 nvidia-drm.fbdev=1` kernel params
- `services.xserver.videoDrivers = ["nvidia"]`
- `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable`
- `hardware.nvidia.open = true; nvidiaSettings = true; modesetting.enable = true; powerManagement.enable = false`
- `hardware.nvidia-container-toolkit.enable = true` (GPU passthrough for Docker)
- `hardware.opentabletdriver.enable = true; daemon.enable = true` (graphics tablet)
- `hardware.uinput.enable = true` + `boot.kernelModules = ["uinput"]` — required for kanata `danger-enable-cmd`
- `boot.blacklistedKernelModules = ["wacom"]` — prevents Wacom kernel driver from conflicting with opentabletdriver

**Storage:**
- systemd-boot, `efi.canTouchEfiVariables = true`
- `/` → ext4, UUID `b6d238cf-8b98-46ed-aebd-760d84b989d8`
- `/boot` → vfat, UUID `083D-D05F`
- swap → UUID `d1c78038-4503-4b32-ab7a-19c212123a0f`

**initrd:** `xhci_pci thunderbolt nvme ahci usb_storage usbhid sd_mod`

**Modules:** all `Tn-*` modules + `Home-xin` (currently stripped)

### Kvasir (laptop)

**Extra module:** `inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s` (handles fan control, power management, display quirks)

**Hardware:**
- Intel CPU only, no Nvidia
- Same opentabletdriver, uinput, wacom blacklist
- No swap partition

**Storage:**
- systemd-boot, `efi.efiSysMountPoint = "/boot"`
- `/` → ext4, UUID `a045a989-af05-492d-9268-2a6479df0487`
- `/boot` → vfat, UUID `9D34-376A`

**Modules:** identical to Akmon (currently stripped)

### Common user config (both hosts)

```nix
users.mutableUsers = false;
users.users.xin = {
  isNormalUser = true;
  hashedPasswordFile = config.sops.secrets.xin-password.path;
  shell = pkgs.zsh;
  extraGroups = [ "wheel" "docker" "ydotool" "scanner" "lp" "uinput" "input" "dialout" "plugdev" ];
};
```

`system.stateVersion = "23.11"` on both. Current skeleton uses `extraGroups = [ "wheel" "networkmanager" ]` only.

---

## 6. Core Modules

### Tn-nix (`Core/nix-settings.nix`)

- `nix.settings.experimental-features = ["nix-command" "flakes"]`
- `programs.nix-index.enable = true` + `programs.nix-index-database.comma.enable = true` — the `,` command runs any package without installing it
- `programs.nh`: cleaner nixos-rebuild wrapper; `clean.enable = true; clean.extraArgs = "--keep-since 6d --keep 3"` (auto-GC); `flake = "/home/xin/Projects/Technonomicon/"` hardcoded
- `nixpkgs.config.allowUnfree = true`

### Tn-desktop (`Core/desktop.nix`)

**Hardware:**
- `hardware.bluetooth.enable = true`
- `hardware.graphics.enable = true`
- `hardware.xpadneo.enable = true` — Xbox gamepad driver
- `hardware.sane.enable = true; extraBackends = [pkgs.sane-airscan]` — scanning with WiFi scanner support

**Services:**
- `services.libinput.enable = true` — touchpad: `tappingDragLock = false; middleEmulation = false`
- `services.gnome.gnome-keyring.enable = true` — credential storage for GUI apps
- `services.pulseaudio.enable = false` — explicitly disabled, replaced by PipeWire
- `services.pipewire.enable = true; pulse.enable = true; alsa.enable = true; alsa.support32Bit = true`
- `services.logind.settings.Login.HandleSuspend = "ignore"` — suspend handled by hypridle, not logind

**Fonts:**
- `iosevka` — primary terminal/editor font
- `iosevka-comfy.comfy-wide-motion` + `.comfy-wide-motion-duo` — holdover from Emacs era, kept
- `jetbrains-mono` — used in hyprlock clock
- `sarasa-gothic` — CJK support with Latin alignment
- `noto-fonts` — broad Unicode coverage fallback
- `overpass`, `fira-code`, `fira-go` — UI/web fonts
- `julia-mono` — Julia language symbols
- `cm_unicode` — Computer Modern Unicode (LaTeX-style math)
- `nerd-fonts.symbols-only` — icon glyphs for waybar/starship

**MIME defaults:**
- `application/pdf` → `sioyek.desktop`
- `text/html`, `application/xhtml+xml`, `x-scheme-handler/http(s)/about/unknown/mailto` → `brave-browser.desktop`

**udev rules:**
- `KERNEL=="ttyACM[0-9]*", MODE="0666"` — microcontroller serial (world-readable)
- `KERNEL=="ttyUSB[0-9]*", MODE="0666"` — USB serial
- `KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"` — kanata needs uinput at group level

**XDG portals:** `xdg-desktop-portal-gtk` + `xdg-desktop-portal-hyprland` — both needed; Hyprland portal handles screen sharing, GTK portal handles file pickers

**Programs:**
- `programs.steam.enable = true`
- `programs.ydotool.enable = true` — Wayland automation (no X required)
- `programs.appimage.enable = true; binfmt = true` — AppImage binfmt interpreter; extra packages: `libepoxy brotli xdg-user-dirs`
- `programs.dconf.enable = true` with:
  - `org/gnome/desktop/interface`: `color-scheme = "prefer-dark"; gtk-theme = "Adwaita-dark"`
  - `org/virt-manager/virt-manager/connections`: `autoconnect = ["qemu:///system"]; uris = ["qemu:///system"]`

**environment.etc:**
- `xdg/user-dirs.defaults`: DESKTOP=Archive, DOWNLOAD=Downloads, TEMPLATES=Projects, PUBLICSHARE=Projects, DOCUMENTS/MUSIC/PICTURES/VIDEOS=Media — flat directory philosophy
- `xdg/gromit-mpx.cfg` + `xdg/gromit-mpx.ini` — screen annotation tool configs
- `gtk-3.0/settings.ini` + `gtk-4.0/settings.ini`: `gtk-theme-name=Adwaita-dark; gtk-application-prefer-dark-theme=1`

**Packages:** `gromit-mpx`, `brightnessctl`, `gnome-themes-extra`, `adwaita-icon-theme`, `kdePackages.skanlite`, `blueman`, `pavucontrol`, `inputs.plover-flake.packages.<system>.plover-full`

### Tn-network (`Core/network.nix`)

- `networking.networkmanager.enable = true; wifi.backend = "iwd"` — iwd is faster and lower power than wpa_supplicant
- `/etc/hosts` blocks `reddit.com`, `www.reddit.com`, `old.reddit.com` on IPv4 + IPv6 — intentional distraction prevention
- `time.timeZone = "America/Detroit"`
- Firewall: TCP `[7236 7250]`, UDP `[7236]`, `trustedInterfaces = ["p2p-wl+"]` — Miracast/WiFi Direct casting
- udev: `SUBSYSTEM=="net", KERNEL=="p2p-dev-*", ACTION=="add", TAG-="systemd"` — prevents p2p-dev interfaces from being tracked by systemd
- `services.avahi.enable = true; nssmdns4 = true; openFirewall = true` — mDNS for printers and local services
- `programs.gnupg.agent.enable = true; enableSSHSupport = true` — single agent for both GPG and SSH
- `services.openssh.enable = false; settings.PermitRootLogin = "no"; PasswordAuthentication = false` — no remote access
- `services.printing.enable = true`
- Syncthing: `enable = true; openDefaultPorts = true; guiAddress = "127.0.0.1:8385"` (shifted from default 8384); `user = "xin"; group = "users"; dataDir = "/home/xin/"`
- Packages: `impala` (TUI WiFi), `gping` (graphical ping)

### Tn-shell (`Core/shell.nix`)

**Xonsh:**
- `programs.xonsh.enable = true` — primary interactive shell (Kvasir); config from `Core/_config.xsh`
- Custom Python packages built inline (not from nixpkgs):
  - `xontrib-fzf-widgets` from `github:laloch/xontrib-fzf-widgets@master` — fzf key bindings for xonsh
  - `xonsh-direnv` v1.6.5 from `github:74th/xonsh-direnv` — direnv xontrib

**Zsh:**
- `programs.zsh.enable = true; enableCompletion = true` — system-level; also configured in home-manager `_shell.nix`

**Direnv:** `programs.direnv.enable = true; nix-direnv.enable = true` — automatic per-project nix-shell

**Starship prompt:**
- Format: `$directory$nix_shell$git_branch$git_commit$git_state$git_status\n$character` — no hostname, no time, no command duration
- Primary color: `#539bf5` (blue); error color: `#ff4b00`
- `success_symbol = "[❯](#539bf5)"`, `error_symbol = "[✗](#ff4b00)"`
- directory: `truncate_to_repo = true; fish_style_pwd_dir_length = 3; read_only = " "`
- git status symbols (all blue): conflict, staged, modified, renamed, deleted, untracked `?`, stashed, ahead, behind

**System packages:**

| Package | Purpose |
|---|---|
| `nix-your-shell` | xonsh/zsh shell integration for `nix develop`/`nix shell` |
| `gitFull` + `git-lfs` | Version control |
| `ghostty` | Primary terminal emulator |
| `claude-code` | AI coding assistant CLI |
| `btop` / `nmon` / `kmon` | System/kernel monitoring |
| `rsync` / `rclone` | File sync |
| `wget` / `curl` | HTTP fetch |
| `glib` | GIO utilities (gio, gvfs tools) |
| `unzip` / `zip` / `bzip3` | Archives |
| `nix-ld` | Run unpatched dynamic binaries |
| `zoxide` | Smart `cd` with frecency |
| `gparted` | Disk partitioning GUI |
| `pciutils` / `usbutils` | Hardware enumeration |
| `fastfetch` | System info display |
| `udiskie` | Automount removable media |
| `trash-cli` | Safe delete (moves to trash) |
| `ripgrep` / `ripgrep-all` | Fast grep |
| `fd` | Fast find |
| `eza` | Modern ls |
| `entr` | Re-run commands on file change |
| `progress` | Progress for coreutils |
| `copyq` | Clipboard manager with history |
| `caligula` | Disk image burn tool |
| `gum` | TUI script components |
| `sc-im` | TUI spreadsheet |
| `gh` / `glab` | GitHub/GitLab CLI |
| `jq` / `yq` | JSON/YAML processing |
| `dysk` | Disk usage TUI |
| `pastel` | Color manipulation CLI |
| `gnumake` | Build tool |
| `antigravity-fhs` | FHS environment for unpackaged binaries |
| `bat` | Cat with syntax highlighting |
| `mpv` | Media player |
| `sox` | Audio processing CLI |
| `aria2` | Multi-connection download manager |
| `nemo-with-extensions` | GUI file manager |
| `nvtopPackages.full` | GPU monitoring (Nvidia + AMD + Intel) |
| `zellij` | Terminal multiplexer |
| `yazi` | TUI file manager |
| `glow` / `presenterm` / `frogmouth` | Markdown viewers/presenters |

### Tn-sound (`Core/sound.nix`)

- `wiremix` — TUI PipeWire mixer
- `alsa-utils` — ALSA command-line tools

### Tn-utf (`Core/utf.nix`)

- `i18n.defaultLocale = "en_US.UTF-8"`; all `LC_*` variables explicitly set to `en_US.UTF-8`
- `i18n.supportedLocales = ["en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" "ko_KR.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8"]` — academic language requirements
- Input method: `i18n.inputMethod.type = "fcitx5"; enable = true; fcitx5.waylandFrontend = true`
- fcitx5 addons:
  - `fcitx5-gtk` — GTK IM module
  - `qt6Packages.fcitx5-chinese-addons` — Pinyin, Cangjie, etc.
  - `fcitx5-hangul` — Korean input
  - `fcitx5-mozc-ut` — Japanese input (mozc with UT dictionary)
  - `qt6Packages.fcitx5-configtool` — GUI config
  - `fcitx5-nord` — Nord color theme
- `environment.etc."xdg/fcitx5/config".source = ./_fcitx5-config`

### Tn-virtualization (`Core/virtualization.nix`)

- `virtualisation.libvirtd.enable = true; qemu.package = pkgs.qemu_kvm; qemu.swtpm.enable = true` — TPM emulation for Windows 11 guests
- `virtualisation.docker.enable = true`
- `virtualisation.spiceUSBRedirection.enable = true`
- `users.users.xin.extraGroups = ["libvirtd" "tty"]`
- `programs.virt-manager.enable = true; programs.dconf.enable = true`
- Packages: `spice`, `spice-gtk`, `spice-protocol`, `virt-viewer`, `distrobox`
- `distrobox` is the stopgap for sagemath (broken in nixpkgs at current rev)

---

## 7. Desktop Modules

### Tn-display-manager (`Desktop/display-manager.nix`)

- `services.greetd.enable = true`
- Session command: `tuigreet --time --asterisks --remember --sessions <wayland-sessions-path>`
- Session user: `greeter`
- systemd service config: `Type = "idle"` (waits for system to settle before showing login), `TTYReset = true; TTYVHangup = true; TTYVTDisallocate = true` — full TTY cleanup after session ends
- No X11 display manager — pure Wayland from boot

### Tn-hyprland (`Desktop/hyprland.nix`)

- `programs.hyprland.enable = true; withUWSM = true` — UWSM (Universal Wayland Session Manager) manages systemd integration and environment variable propagation
- `security.pam.services.hyprlock = {}` — registers PAM service for screen lock authentication
- Session variables: `NIXOS_OZONE_WL=1`, `ELECTRON_OZONE_PLATFORM_HINT=auto`, `QT_QPA_PLATFORM=wayland`, `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`, `NIXPKGS_ALLOW_UNFREE=1`
- Packages:

| Package | Purpose |
|---|---|
| `hyprlandPlugins.hypr-dynamic-cursors` | Cursor shake-to-find + hide-on-type |
| `hyprlock` | Screen locker |
| `hypridle` | Idle daemon (dim → lock → suspend) |
| `hyprpaper` | Wallpaper daemon |
| `waybar` | Status bar |
| `anyrun` | App launcher |
| `wl-kbptr` | Keyboard-driven pointer (no mouse needed), floated via window rule |
| `grim` + `slurp` | Screenshot (full + region) |
| `wl-clipboard` | Wayland clipboard CLI |
| `wtype` | Wayland xdotool replacement |
| `hyprpicker` | Color picker |
| `satty` | Screenshot annotation |
| `wf-recorder` | Screen recording |
| `awww` | Animated wallpaper daemon |
| `wlogout` | Logout/shutdown menu |
| `nwg-look` | GTK theme picker |
| `hyprshot` | Hyprland screenshot utility |

### Tn-lock (`Desktop/lock.nix`)

Thin module: `programs.hyprlock.enable = true`. Exists so hyprlock can be toggled independently of the hyprland module (e.g., enabling lock on a headless build).

---

## 8. Input — Kanata

### Tn-kanata (`Input/kanata.nix`)

- `services.kanata.enable = true`
- `services.kanata.package = pkgs.kanata-with-cmd` — the `-with-cmd` variant enables shell command execution from kanata
- `keyboards.colmacs.configFile = ../Core/_kanata.kbd` — layout named "colmacs" (Colemak + macOS-style mod behavior)

### Kanata layout (`Core/_kanata.kbd`)

**defcfg:**
- `process-unmapped-keys yes` — remap every key, including media keys
- `concurrent-tap-hold yes` — allows simultaneous home-row mod activation
- `danger-enable-cmd yes` — required for any `cmd` actions
- `linux-continue-if-no-devs-found yes` — don't abort if device not present at boot
- Devices: 4 Kinesis Advantage2 paths (event-if02, event-mouse, if01-event-kbd, mouse) + laptop keyboard (`platform-i8042-serio-0-event-kbd`)

**Base layer: Colemak-DH** with home-row mods and one-shot modifiers applied

**Home-row mods (tap-hold 200ms tap / 250ms hold):**

| Key (Colemak) | Tap | Hold |
|---|---|---|
| R | r | lalt |
| S | s | lmet (Super) |
| T | t | lctl |
| F | f | lsft |
| P | p | lsft |
| N | n | rctl |
| E | e | rmet |
| I | i | ralt |
| L | l | rsft |
| U | u | rsft |

**One-shot modifiers** (on physical modifier keys, tap-hold 250ms/250ms): tap = one-shot 1500ms window, hold = sticky modifier. Covers lsft/rsft, lctl/rctl, lmet/rmet, lalt/ralt.

**Special aliases:**
- `spc-nav` / `bspc-nav` — tap Space/Backspace, hold activates nav layer (tap-hold 200/350)
- `sret` — tap Return, hold rmet (tap-hold 250/250)
- `sdel` — tap Delete, hold rmet
- `nesc` — tap Escape, hold activates num layer (tap-hold 250/250)
- `mouse` / `mouse-2` — multi-modifier chords (lctl+lalt+lmet+lsft+spc/ret) for mouse emulation

**Nav layer** (hold Space or Backspace):

```
Shift+Left   PgUp   Shift+Right   [mouse-2]
Ctrl+Left    Up     Ctrl+Right    [mouse]
Home         PgDn   End
Left         Down   Right
```

**Num layer** (hold Escape): numpad layout on HJKL cluster

```
0 7 8 9
0 4 5 6
0 1 2 3
0
```

---

## 9. Academic Modules

### Tn-documents (`Academic/documents.nix`)

| Package | Purpose |
|---|---|
| `texlive.combined.scheme-full` | Full LaTeX distribution |
| `typst` | Modern typesetting language |
| `tinymist` | Typst LSP |
| `pandoc` | Universal document converter |
| `quarto` | Scientific publishing (R/Python/Julia notebooks → PDF/HTML) |
| `mermaid-cli` | Diagram generation from text |
| `drawio` | Flowchart/diagram GUI |
| `pdf2svg` | PDF → SVG conversion |
| `poppler` | PDF manipulation utilities |
| `pdfannots2json` | Extract PDF annotations |
| `hunspell` + `hunspellDicts.en_US` | Spell checking |

### Tn-math (`Academic/math.nix`)

| Package | Purpose |
|---|---|
| `julia` | Scientific computing language |
| `R` + `languageserver` + `tidyverse` + `rmarkdown` + `knitr` | Statistical computing |
| `maxima` | Computer algebra system (CAS) |
| `octave` | MATLAB-compatible numerical computing |
| `gnuplot` | Plotting |
| `lean4` | Interactive theorem prover |
| `gap` | Group theory / algebra |
| `polymake` | Polyhedral and combinatorial geometry |
| `macaulay2` | Algebraic geometry, homological algebra, sheaf theory |
| Python bundle | numpy, scipy, matplotlib, sympy, pandas, jupyter, jupyterlab, scikit-learn, ipython, **gudhi** (TDA / persistent homology) |
| `zeromq` | Jupyter kernel communication protocol |

Note: `sagemath` is commented out — broken at the current nixpkgs-unstable rev. Use distrobox as stopgap.

### Tn-references (`Academic/references.nix`)

- `zotero` — reference manager (BibTeX export, browser integration)
- `foliate` — ebook reader (EPUB, MOBI, PDF)
- `zathura` — lightweight PDF/document viewer
- `libation` — Audible audiobook DRM removal and management

### Tn-anki (`Academic/anki.nix`)

- `anki-bin` — spaced repetition flashcard application
- udev rules at `/etc/udev/rules.d/70-javelin.rules`:
  - `SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0003", TAG+="uaccess"` — RP2040 bootloader for Javelin steno firmware flashing
  - `KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"` — generic HID for Javelin WebHID tools

---

## 10. Knowledge Modules

### Tn-pdf (`Knowledge/pdf.nix`)

- `sioyek` — academic PDF reader with keyboard navigation and citation lookup
- Wrapped with `makeWrapper --set QT_QPA_PLATFORM xcb` — forces X11/XCB backend; native Wayland sioyek has rendering issues
- MIME default: `application/pdf → sioyek.desktop` (set in `Tn-desktop`)

**`/etc/sioyek/prefs_user.config`:**

| Setting | Value | Notes |
|---|---|---|
| `default_dark_mode` | 1 | Always start in dark mode |
| `dark_mode_background_color` | `0.1 0.1 0.1` | Near-black background |
| `dark_mode_contrast` | `0.8` | Slight contrast reduction |
| `ruler_mode` | 1 | Horizontal ruler line for reading |
| `super_fast_search` | 1 | Index-based fast search |
| `should_launch_new_window` | 1 | Each document opens in a new window |
| `vertical_move_amount` | `1.0` | One line per scroll step |
| `search_url_g` | Google | `s` key → web search |
| `search_url_s` | Google Scholar | `s` key with Scholar |
| `search_url_a` | arXiv | arXiv search |
| `search_url_l` | LibGen | Library Genesis |
| `inverse_search_command` | `emacsclient -n +%2 "%1"` | Legacy holdover; Emacs daemon no longer default |

**`/etc/sioyek/keys_user.config`:** Remapped for Colemak: `u`=move_up, `e`=move_down, `v`=keyboard_select, `<f8>`=toggle_dark_mode, `/`=regex_search, `s`=external_search

### Tn-learning (`Knowledge/learning.nix`)

- `ledger` — double-entry accounting CLI (hledger-compatible format)
- `fava` — web UI for Beancount ledgers
- `beancount` — structured accounting language
- `gnucash` — full-featured accounting GUI
- `rnote` — note-taking and drawing app; wrapped with `makeWrapper --set GDK_BACKEND x11` — Wayland rnote has rendering issues, X11 backend stable

---

## 11. Productivity Modules

### Tn-tasks (`Productivity/tasks.nix`)

- `taskwarrior3` — task management with contexts, urgency, reports
- `timewarrior` — time tracking integrated with taskwarrior
- `taskwarrior-tui` — terminal UI for taskwarrior

### Tn-mail (`Productivity/mail.nix`)

- `thunderbird` — GUI email client; configured in `Home/xin/_mail.nix`
- `tbkeys` — Thunderbird extension for vim-style keyboard navigation (to be installed as a Thunderbird extension, not via Nix)
- `aerc` — TUI email client
- `notmuch` — fast email indexer and search
- `isync` (mbsync) — IMAP → Maildir sync
- `msmtp` — SMTP relay (sends mail from local MUAs)

### Tn-calendar (`Productivity/calendar.nix`)

- `khal` — TUI calendar (reads/writes iCalendar files)
- `vdirsyncer` — CalDAV/CardDAV sync to local files
- `calcurse` — combined TUI calendar and to-do
- Google Calendar accessed via Brave web-app desktop entry (see Tn-web-apps)

### Tn-quantified (`Productivity/quantified.nix`)

| Package | Purpose |
|---|---|
| `dijo` | Habit tracker (TUI) |
| `porsmo` | Pomodoro timer (TUI) |
| `wtfutil` | Customizable dashboard (TUI) |
| `activitywatch` | Automatic window-level time tracking |
| `haskellPackages.arbtt` | Window time tracker (X11/Wayland log-based) |
| `hledger` + `hledger-ui` + `hledger-web` | Plain-text double-entry accounting |
| `datasette` | SQLite web explorer |
| `visidata` | TUI spreadsheet and data exploration |

`services.arbtt.enable = true` — arbtt systemd service enabled

**Habitica → Taskwarrior integration (planned):**
- A hook script in `~/.task/hooks/on-modify.habitica` syncs task completion events to Habitica via its REST API
- Requires `habitica-api-key` and `habitica-user-id` in sops secrets
- The hook POSTs to `https://habitica.com/api/v3/tasks/user` on task completion

### Tn-backup (`Productivity/backup.nix`)

- `borgbackup` — deduplicated, encrypted, compressed backups (passphrase stored in sops; not yet added)

---

## 12. Web Modules

### Tn-web-browsers (`Web/browsers.nix`)

**Chromium:** `programs.chromium.enable = true` — registers Chromium in NixOS, needed for Ozone/Wayland paths even if Brave is primary

**Brave:**

Overridden with command-line flags:
- `--enable-features=UseOzonePlatform` — Wayland rendering
- `--ozone-platform=wayland`
- `--disable-features=BraveNews,BraveRewards,BraveWallet,WebRtcAllowInputVolumeAdjustment`
- `--hide-crash-restore-bubble`

`postFixup` injects `initial_preferences` JSON into the Brave binary directory: `{ "browser": { "custom_chrome_frame": true } }`

**Managed policy** (`/etc/brave/policies/managed/default.json`) — enforced, not overridable by user:

| Policy | Value | Notes |
|---|---|---|
| `PasswordManagerEnabled` | false | Use Bitwarden extension instead |
| `AutofillAddressEnabled` | false | |
| `AutofillCreditCardEnabled` | false | |
| `BraveRewardsDisabled` | true | |
| `BraveWalletDisabled` | true | |
| `BraveVPNMode` | 0 | Disabled |
| `TorDisabled` | true | |
| `IPFSCompanionEnabled` | false | |
| `DefaultBrowserSettingEnabled` | false | Don't prompt to set as default |
| `MetricsReportingEnabled` | false | |
| `SearchSuggestEnabled` | false | |
| `ShowHomeButton` | false | |
| `NewTabPageLocation` | `https://en.wikipedia.org/wiki/Special:Random` | Random Wikipedia article as new tab |
| `HomepageLocation` | same | |
| `BraveNewTabWidgetsVisible` | false | |
| `NewTabPageAllowedTypes` | `["none"]` | |
| `ImagesForNewTabPageEnabled` | false | |

**Force-installed extensions** (Chrome Web Store IDs):

| Extension ID | Name |
|---|---|
| `gfbliohnnapiefjpjlpjnehglfpaknnc` | Surfingkeys — vim-style keyboard navigation |
| `eimadpbcbfnmbkopoojfekhnkhdbieeh` | Dark Reader |
| `nngceckbapebfimnlniiiahkandclblb` | Bitwarden — password manager |
| `cjpalhdlnbpafiamejdnhcphjbkeiagm` | uBlock Origin |
| `dndlcbaomdoggooaficldplkcmkfpgff` | New Tab, New Window — no-tabs extension (core to the single-level-depth philosophy) |
| `blaaajhemilngeeffpbfkdjjoefldkok` | LeechBlock NG — site/time blocker |

**Nyxt 4.0:** commented out — AppImage URL and hash not yet filled in.

### Tn-web-apps (`Web/web-apps.nix`)

All entries are `makeDesktopItem` launching Brave in `--app=<URL> --start-maximized` (PWA/SSB mode, no browser chrome). Categories: `["Application" "Network"]`.

| App Name | URL |
|---|---|
| Discord App | `https://www.discord.gg/channels/@me` |
| Khan Academy | `https://www.khanacademy.org` |
| TOP: The Odin Project | `https://www.theodinproject.com/dashboard` |
| YouTube | `https://www.youtube.com` |
| Gemini | `https://gemini.google.com/app` |
| Steno Jig | `https://joshuagrams.github.io/steno-jig/form.html` |
| Typey Type | `https://didoesdigital.com/typey-type/lessons/` |
| Gmail | `https://gmail.com` |
| Google Calendar | `https://calendar.google.com` |
| Toggl | `https://track.toggl.com/timer` |
| Syncthing | `http://localhost:8385/` |
| Exercism | `https://exercism.org/dashboard` |

### Tn-communication (`Web/communication.nix`)

- `newsflash` — RSS/Atom feed reader with Feedly/Miniflux sync
- `mako` — Wayland notification daemon (also configured in home-manager `_apps.nix`)

### Tn-games (`Web/games.nix`)

- `xivlauncher` — Final Fantasy XIV launcher (Linux-compatible, handles Wine/DXVK setup)
- `hyperspeedcube` — twisty puzzle simulator (Rubik's cube variants)
- `exercism` — programming practice CLI (downloads/submits exercises)

---

## 13. Art Modules

### Tn-art (`Art/art.nix`)

| Package | Purpose |
|---|---|
| `openscad` + `openscad-lsp` | Parametric 3D CAD + LSP |
| `graphviz` | Graph visualization (dot language) |
| `obs-studio` | Screen recording and streaming |
| `vlc` | Media player |
| `inkscape-with-extensions` | Vector graphics |
| `gimp-with-plugins` | Raster image editing |
| `krita` | Digital painting |
| `blender` | 3D modeling and animation |
| `pureref` (local) | Reference image organizer |
| `allusion` (local) | Image library / visual research |
| `yt-dlp` | YouTube and media downloader |
| `ffmpeg` | Video/audio transcoding |
| `wl-color-picker` | Wayland color picker |
| `pinta` | Simple image editor |

`cura-appimage` is commented out — broken at this nixpkgs rev (AppImage extract API change).

**OpenSCAD config** (`/etc/xdg/OpenSCAD/OpenSCAD.conf`): DeepOcean colorscheme, `autoReload=true`, orthographic projection, axes visible, all toolbars/console/customizer/editor hidden (minimal UI).

**Desktop items:** `allusion` and `pureref` registered as XDG desktop entries with bundled PNG icons.

### Local AppImage derivations

`Art/PureRef/_pureref.nix` and `Art/Allusion/_allusion.nix` both use the same pattern:

```nix
pkgs.runCommand "appname" {} ''
  mkdir -p $out/bin
  cp ${src} $out/bin/appname.AppImage
  chmod +x $out/bin/appname.AppImage
  echo '#!/bin/sh
exec $out/bin/appname.AppImage "$@"' > $out/bin/appname
  chmod +x $out/bin/appname
''
```

Versions: PureRef 2.0.3 x64, Allusion 1.0.0-rc.10. Binary blobs (AppImages + icons) are committed to the repo — intentional for reproducibility, since no upstream Nix packages exist for these proprietary tools.

---

## 14. Home Manager

### Home-xin (`Home/xin/default.nix`)

- home-manager loaded as NixOS module (`inputs.home-manager.nixosModules.home-manager`)
- `useGlobalPkgs = true; useUserPackages = true` — shares nixpkgs instance with system, no separate eval
- `backupFileExtension = "backup"` — conflict safety when deploying
- `extraSpecialArgs = { inherit inputs; }` — passes flake inputs to all home-manager sub-modules
- `home.stateVersion = "23.11"`
- Sub-modules imported: `_shell.nix`, `_git.nix`, `_hyprland.nix`, `_neovim.nix`, `_taskwarrior.nix`, `_mail.nix`, `_rclone.nix`, `_apps.nix`

### _apps.nix

- `home.file.".config/surfingkeys/config.js"` — deploys `Modules/Web/_surfingkeys.js`
- `home.file.".config/discord/settings.json"` — `{ "SKIP_HOST_UPDATE": true }` prevents Discord auto-update lockout on NixOS
- Ghostty terminal config (`~/.config/ghostty/config`):
  - `font-family = Iosevka; font-size = 13`
  - `theme = custom-dark`
  - `cursor-style = block; cursor-style-blink = false`
  - `shell-integration-features = no-cursor` — disables shell integration cursor override
  - `window-padding-x = 8; window-padding-y = 6`
  - `background-opacity = 0.97; background-blur-radius = 20`
- Ghostty `custom-dark` theme (`~/.config/ghostty/themes/custom-dark`):
  - background `1D232F`, foreground `CFDFDF`, cursor `00FFFF` (cyan)
  - selection-background `2E3A4E`, selection-foreground `CFDFDF`
  - 16-color palette: dark blue-grey backgrounds, red/green/yellow/blue/purple/cyan accents, saturated variants for bright colors
- `services.mako.enable = true; settings.default-timeout = 3000`

### _git.nix

- `programs.git.enable = true; userName = "xin"; userEmail = "git@ironshark.org"`
- Global ignores: `*~`, `.*~`, `#*#`, `\#*\#`, `.*.swp` (Emacs and Vim temp files)
- Aliases:
  - `send` — `git status && read CommitMessage && git add . && git commit -m "$CommitMessage" && git push`
  - `unstage` — `restore --staged`
  - `history` — `log --graph --pretty=oneline`
  - `last` — `log -1 HEAD`
- `init.defaultBranch = "main"; pull.rebase = false; push.default = "current"`

### _hyprland.nix

All Hyprland-related home-manager configuration. Uses the Lua config API.

**Plugin:** `hypr-dynamic-cursors.so` loaded at startup

**Monitor:** `output = ""` (auto-detect), mode=preferred, position=auto, scale=auto. Host-specific entries commented out:
- Akmon: `DP-1 2560x1440@144 scale=1`
- Kvasir: `eDP-1 2560x1440@60 scale=1.5`
These must be uncommented/set per-host after first deploy.

**Autostart (on `hyprland.start`):** `mako`, `hypridle`, `hyprpaper`, `waybar`, `ghostty --class=ghostty-scratchpad`, `ghostty --class=ghostty-nvim -e nvim`, `udiskie`, `copyq`, `fcitx5 -d`, `aw-server`, `aw-watcher-window`, `aw-watcher-afk`

**hl.config:**

| Section | Key settings |
|---|---|
| general | `gaps_in=4; gaps_out=8; border_size=2; active_border=rgba(00FFFFee); inactive_border=rgba(1D232Faa); layout=dwindle` |
| decoration | `rounding=6; blur.enabled=true; blur.size=4; blur.passes=2` |
| animations | bezier `snappy` (0.05,0.9 / 0.1,1.05); windows/fade/workspaces speed=3/4/4 |
| misc | `disable_hyprland_logo=true; disable_splash_rendering=true` |
| input | `kb_layout=us; repeat_delay=500; repeat_rate=30`; touchpad: `natural_scroll=false; tap_to_click=true; disable_while_typing=true; middle_button_emulation=false` |
| cursor | `hide_on_key_press=true; inactive_timeout=5` |
| xwayland | `force_zero_scaling=true` |
| dynamic-cursors | `mode=none`; shake: `enabled=true; threshold=6.0; base=4.0; speed=4.0; timeout=2000` |

**Window rules:**
- `ghostty-scratchpad` → `workspace special:terminal silent`, float, size 65%×60%, center — the quick-shell-for-utilities pattern
- `ghostty-nvim` → `workspace name:nvim silent` — dedicated nvim workspace
- `pavucontrol`, `blueman-manager`, `wl-kbptr` → float

**Keybindings** (all with `mod=SUPER`, Colemak-oriented):

| Binding | Action |
|---|---|
| `1–9` | Focus workspace 1–9 / Move window to workspace 1–9 (with SHIFT) |
| `Space` | Focus workspace `name:nvim` — jump to nvim from anywhere |
| `Return` | Open anyrun launcher |
| `T` | Launch ghostty |
| `` ` `` | Toggle special workspace "terminal" (scratchpad) |
| `Q` | hyprlock |
| `SHIFT+Q` | wlogout |
| `D` | Close focused window |
| `W` | Toggle float |
| `F` | Fullscreen |
| `SHIFT+F` | Maximize |
| `M/I/N/E` | Focus left/right/down/up (Colemak NEIO home row) |
| `SHIFT+M/I/N/E` | Move window left/right/down/up |
| `ALT+M/I/N/E` | Resize window ±40px (repeating) |
| `Y` | `slurp \| grim -g - - \| wl-copy` (region screenshot to clipboard) |
| `SHIFT+Y` | hyprshot region |
| `CTRL+Y` | wf-recorder (screen record) |
| `P` | hyprpicker (color picker) |
| `K` | wl-kbptr (keyboard pointer, floated) |

**programs.hyprlock:**
- `general.hide_cursor = true`
- background: `blur_passes=3; blur_size=8; noise=0.012; contrast=0.89; brightness=0.72`
- input-field: size 320×52, `outline_thickness=2`, `outer_color=rgb(00FFFF)` (cyan), `inner_color=rgb(1D232F)`, `font_color=rgb(CFDFDF)`, `fade_on_empty=true`, `check_color=rgb(00FA9A)`, `fail_color=rgb(FF5370)`, position `0,-120`
- label 1: `$TIME`, font_size=72, JetBrains Mono, `rgba(CFDFDFee)`, position `0,100`
- label 2: date `cmd[update:60000] date '+%A, %B %d %Y'`, font_size=18, `rgba(8C98A6cc)`, position `0,20`

**services.hypridle:**
- `lock_cmd = "hyprlock"; before_sleep_cmd = "hyprlock"; after_sleep_cmd = "hyprctl dispatch dpms on"`
- Listener 1: timeout=240s → `brightnessctl -s set 20%` / on-resume `brightnessctl -r`
- Listener 2: timeout=300s → `hyprlock`
- Listener 3: timeout=600s → `systemctl suspend`

**programs.waybar:**
- `layer=top; position=top`
- modules-left: `hyprland/workspaces`, `hyprland/window`; center: `clock`; right: `tray`, `wireplumber`, `network`, `cpu`, `memory`, `battery`, `backlight`
- workspaces: format `{id}`, on-click=activate
- clock: `{:%H:%M}` / alt `{:%A, %B %d %Y}`; tooltip shows full calendar
- wireplumber: `  {volume}%`, muted=`" "`, on-click=pavucontrol, max-volume=150, scroll-step=5
- network: wifi `  {essid}`, ethernet ` {ifname}`, disconnected `󰌙 `
- cpu: ` {usage}%`, interval=5
- memory: ` {used:0.1f}G`, interval=10
- battery: icons `["","","","",""]`, warning=30, critical=15
- backlight: icons `["","",""]`
- CSS: background `#1D232F`, foreground `#CFDFDF`, border-bottom `2px solid #00FFFF`; active workspace `color: #00FFFF`, clock `#00FFFF`, inactive modules `#8C98A6`; font: Iosevka + Symbols Nerd Font 13px

### _neovim.nix

Uses `inputs.lazyvim-nix.homeManagerModules.default` (pfassina/lazyvim-nix).

**programs.lazyvim:**
- `enable = true; installCoreDependencies = true`
- `extraPackages = [pkgs.lua-language-server]`

**Language extras** (all `installDependencies = true` unless noted):
`nix`, `python`, `haskell`, `zig`, `clangd`, `typst`, `tex`, `r`, `markdown` (no installDependencies)

**Editor extras:** `telescope`, `neo-tree`, `harpoon2`

**UI extras:** `indent-blankline`

**Coding extras:** `luasnip`, `nvim-cmp`

**Vim options:**
```lua
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.scrolloff = 10
vim.opt.signcolumn = "yes"
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 250
```

**Custom plugins:**

| Plugin | Details |
|---|---|
| **colorscheme** | `scottmckendry/cyberdream.nvim` — lazy=false, priority=1000, italic_comments=true; `folke/tokyonight.nvim` disabled |
| **vimtex** | `lervag/vimtex`; viewer=sioyek, compiler=latexmk; `<leader>lc/lv/le` |
| **neogit** | `NeogitOrg/neogit` + plenary + diffview; `<leader>gg` |
| **undotree** | `mbbill/undotree`; `<leader>u` |
| **toggleterm** | `akinsho/toggleterm.nvim`, direction=float; `<F4>` toggle, `<leader>tt` taskwarrior-tui |
| **obsidian** | `epwalsh/obsidian.nvim`; workspace "Grimoire" at `~/Grimoire`; daily_notes in `Journal/` with `%Y-%m-%d` template + `Templates/Daily.md`; keys `<leader>on/of/od/ot/ol` |
| **molten** | `benlubas/molten-nvim` + `3rd/image.nvim` + `HakonHarnes/img-clip.nvim`; image_provider=image.nvim, auto_open_output=true — Jupyter kernel runner inside Neovim |

### _mail.nix

**Thunderbird** (home-manager `programs.thunderbird`):
- `profiles.xin.isDefault = true`
- Settings: `mail.spellcheck.inline = false`, sort by date descending (`mailnews.default_sort_type=18, default_sort_order=2`)
- tbkeys: installed as a Thunderbird extension (not via Nix); provides vim-style keybindings (j/k navigation, d=delete, r=reply, etc.)

**aerc** (`~/.config/aerc/aerc.conf`):
- [ui]: `timestamp-format = 2006-01-02 15:04`, sidebar-width=28, preview-height=12
- [viewer]: `pager = less -R`, `alternatives = text/plain,text/html`, `header-layout = From,To|Cc,Date,Subject`
- [compose]: `editor = nvim`, `header-layout = To,From,Cc,Subject`
- [filters]: `text/html = w3m -T text/html -dump`, `text/plain = cat`

**aerc bindings** (`~/.config/aerc/binds.conf`):
- [messages]: q=quit, j/k=next/prev, g/G=first/last, Enter=open, d=delete-prompt, D=delete, a=archive, r/R=reply, c=compose, /=search, n/N=next/prev result
- [view]: q=close, j/k=next/prev part, J/K=next/prev message, f=forward, r/R=reply, d=delete, a=archive

**mbsync** (`~/.mbsyncrc`):
- IMAPAccount `ironshark`: host `imap.gmail.com`, port 993, user `xin@ironshark.org`, IMAPS
- PassCmd: `sops decrypt --extract '["google-app-password"]' ~/.config/sops/...` (decrypts at runtime)
- Maildir store at `~/.local/share/mail/ironshark/`
- Syncs: all folders except `[Gmail]/*`, plus `[Gmail]/Sent Mail`, `[Gmail]/Starred`, `[Gmail]/All Mail`
- `Create Both; Expunge Both`

**notmuch** (`~/.config/notmuch/config`):
- mail_root: `~/.local/share/mail`; user: `Xin IronShark <xin@ironshark.org>`
- new tags: `unread;inbox;`; exclude: `deleted;spam;`; `synchronize_flags=true`

**Systemd user timer:**
- `mbsync.service`: ExecStart=`mbsync -a`, ExecStartPost=`notmuch new`
- `mbsync.timer`: OnBootSec=2min, OnUnitActiveSec=5min, WantedBy=timers.target

### _rclone.nix

**Systemd user service `rclone-bisync`:**
- After/Wants: `network-online.target`
- ExecStart: `rclone bisync %h/GDrive gdrive: --transfers 8 --drive-chunk-size 128M`

**Timer:** OnBootSec=5min, OnUnitActiveSec=30min, `Persistent=true` — catches up missed sync runs after suspend/reboot

### _shell.nix

**programs.zsh:**
- `enable = true; enableCompletion = true; autosuggestion.enable = true; syntaxHighlighting.enable = true`
- history: size/save=50000, `ignoreDups=true; share=true`
- initExtra: `setopt AUTO_CD EXTENDED_GLOB HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS`; colored man pages via `LESS_TERMCAP_*`; `nix-your-shell zsh`, `zoxide init zsh --cmd cd`, `starship init zsh`, `direnv hook zsh`; fzf Ctrl+R with `--sort --exact`; `chpwd()` → eza auto-ls; Ctrl+Right/Left word navigation

**Shell functions:**
- `nv_clip()` — pipe stdin to nvim
- `y()` — launch yazi and cd to the directory it exits in
- `copypath` — copy CWD to clipboard via wl-copy
- `copyfile <file>` — copy file contents to clipboard
- `pdf-split <file>` — split PDF by bookmarks (uses cpdf via nix-shell)
- `ca` — clear + newlines
- `rg-menu` / `rgx-menu` — ripgrep → fzf interactive
- `fd-menu` / `fdx-menu` — fd → fzf interactive

**Shell aliases:**

| Alias | Expansion |
|---|---|
| `vim` / `vi` | `nvim` |
| `xsh` | `xonsh` |
| `t` | `task` |
| `tw` | `timew` |
| `tl` | `task list` |
| `cat` | `bat` |
| `find` | `fd -g -i` |
| `grep` | `rg -i` |
| `dd` | `caligula burn` |
| `ls` / `ll` / `lx` / `lld` / `lxd` / `lsx` / `ld` | eza variants |
| `tn` / `ps` / `pj` / `dl` | cd shortcuts |
| `gst` | `git status -sb` |
| `gco` | `git checkout` |
| `gl` | `git log --oneline -n 10` |
| `cpv` | `rsync -h --progress` |
| `rm` | `trash-put -v` |
| `rm-s` | `shred -f` |
| `restart` | `sudo reboot` |
| `logout` | `sudo kill -9 -1` |
| `bzip` | `bzip3` |
| `book-dl` | `aria2c -x 16 -s 16` |

**sessionVariables:** `EDITOR=nvim; VISUAL=nvim; SUDO_EDITOR=nvim; TIMER_THRESHOLD=3`

### _taskwarrior.nix

- `programs.taskwarrior.enable = true; dataLocation = "~/.local/share/task"`
- Contexts: `study` (filter: `+study or +class`), `research` (`+research`), `admin` (`+admin`)
- Urgency coefficients: `deadline=12.0; today=10.0`
- `color = "on"`
- `next` report columns: `id, start.age, priority, project, tags, due.relative, description, urgency`
- Sort: `urgency-` (descending urgency)

---

## 15. Config Files Reference

### `Core/_config.xsh` (Xonsh configuration)

- Options: `AUTO_CD=True; COLOR_INPUT=True; HISTCONTROL={'ignoredups'}; COMPLETIONS_CONFIRM=False; UPDATE_COMPLETIONS_ON_KEYPRESS=False; COMPLETIONS_BRACKETS=False; COMPLETION_QUERY_LIMIT=50; TIMER_FORMAT='[Execution Time: {time:.2f}s]'; TIMER_THRESHOLD=3`
- Colored man pages via `LESS_TERMCAP_*` environment variables
- Editor: `SUDO_EDITOR=EDITOR=VISUAL="nvim"`
- Init sequence: `xontrib load direnv`, `xontrib load fzf-widgets`, FZF key bindings (c-r=history, c-s=SSH, c-t=file, c-g=dir), `zoxide init xonsh`, `starship init xonsh`, `nix-your-shell xonsh`; 100 newlines on startup (cleans terminal)
- Directory aliases: `tn` (Technonomicon), `ps` (Projects), `pj`, `dl` (Downloads)
- Event: `@events.on_chdir` → `eza --icons --oneline --group-directories-first --color=always`
- Utilities: `copypath`, `copyfile`, `rg-menu`, `rgx-menu`, `fd-menu`, `fdx-menu`, `monitor_command`, `pdf-split`, `ca`
- Word navigation: `XONSH_CTRL_BKSP_DELETION=True`; `@events.on_ptk_create` hooks Ctrl+Left/Right
- Aliases: same as `_shell.nix` zsh aliases

### `Core/_fcitx5-config`

- `TriggerKeys=` (empty — no default trigger key for input method switch)
- `AltTriggerKeys[0] = Shift_L` — tap Left Shift to cycle input methods
- `EnumerateForwardKeys[0] = Super+Escape`; `EnumerateGroupForwardKeys[0] = Super+space`
- `ActivateKeys[0] = Hangul_Hanja`; `DeactivateKeys[0] = Hangul_Romaja` — for Korean input
- `PrevPage[0] = Up; NextPage[0] = Down; PrevCandidate[0] = Shift+Tab; NextCandidate[0] = Tab`
- `ActiveByDefault = False; ModifierOnlyKeyTimeout = 250`
- `DefaultPageSize = 5; AutoSavePeriod = 30`

### `Core/_gromit-mpx.cfg` (screen annotation)

Tool definitions and modifier mappings for gromit-mpx on the default device:

| Modifier | Tool |
|---|---|
| none | LINE size=6 color=red |
| SHIFT | PEN size=5 color=blue |
| CTRL | PEN size=5 color=yellow |
| Button 2 | PEN size=6 color=green |
| Button 3 | ERASER size=75 |

Additional tools defined: green line, red rectangle, red smoothed (simplify=10, snap=30), red orthogonal (simplify=15, radius=20, minlen=50, snap=40).

### `Core/_gromit-mpx.ini`

```ini
[General]
ShowIntroOnStartup=false
[Drawing]
Opacity=0.95
```

### `Web/_surfingkeys.js` (Brave keyboard navigation)

- `api.unmap('<Ctrl-i>')` + `api.iunmap('<Ctrl-i>')` — disable built-in vim editor
- `api.map('o', 'go')` — open URL in current tab (vs. new tab)
- `api.map('F', 'c')` — open link in background tab
- Visual mode: arrow keys remapped to j/k/h/l
- Dark theme: background `#24272e`, text `#abb2bf`, URL `#61afef`, highlight `#528bff`; omnibar 60% width, centered

---

## 16. Filesystem Layout (current: stripped skeleton)

```
Technonomicon/
├── flake.nix                    # 5 inputs, import-tree auto-discovery
├── flake.lock
├── _secrets.yaml                # sops-nix encrypted secrets (xin-password only for now)
├── .sops.yaml                   # Three age recipient keys
├── .gitattributes               # git-crypt for *.key and Secrets/**
├── CLAUDE.md                    # Claude Code instructions for this repo
├── refactor.md                  # This file — combined reference document
├── Hosts/
│   ├── Akmon/
│   │   ├── akmon.nix            # nixosConfigurations.Akmon (minimal)
│   │   └── _hardware-configuration.nix
│   └── Kvasir/
│       ├── kvasir.nix           # nixosConfigurations.Kvasir (minimal)
│       └── _hardware-configuration.nix
├── Modules/
│   └── .gitkeep                 # Empty — modules added here one feature set at a time
└── Home/
    └── .gitkeep                 # Empty — home-manager modules added here
```

**Full target structure** (reference for what will be re-added):

```
Modules/
├── Academic/                # anki, documents, math, references
├── Art/                     # art.nix + PureRef/ + Allusion/ (AppImages)
├── Core/                    # desktop, network, nix-settings, shell, sound, utf, virtualization
│   ├── _config.xsh          # Xonsh shell config
│   ├── _fcitx5-config       # fcitx5 input method config
│   ├── _gitconfig           # Global git config
│   ├── _gromit-mpx.cfg/.ini # Screen annotation tool config
│   └── _kanata.kbd          # Keyboard remapping layout
├── Desktop/                 # display-manager, hyprland, lock
├── Input/                   # kanata
├── Knowledge/               # learning, pdf
├── Productivity/            # backup, calendar, mail, quantified, tasks
└── Web/
    ├── browsers.nix
    ├── communication.nix
    ├── games.nix
    ├── web-apps.nix
    └── _surfingkeys.js
Home/
└── xin/
    ├── default.nix          # Home-xin module (home-manager entry point)
    ├── _apps.nix            # ghostty, discord, mako, surfingkeys
    ├── _git.nix             # git config
    ├── _hyprland.nix        # hyprland + hyprlock + hypridle + waybar config
    ├── _mail.nix            # thunderbird + aerc + mbsync + notmuch
    ├── _neovim.nix          # lazyvim-nix + plugins
    ├── _rclone.nix          # GDrive bisync timer
    ├── _shell.nix           # zsh config, aliases, functions
    └── _taskwarrior.nix     # taskwarrior contexts and reports
```

---

## 17. Known Issues and Pending Items

| Item | Location | Notes |
|---|---|---|
| All modules stripped | `Modules/`, `Home/` | Intentional — add back one feature set at a time |
| Monitor config commented out | `Home/xin/_hyprland.nix` | Must be set per-host after first deploy |
| sagemath broken | `Modules/Academic/math.nix` | Not in nixpkgs at current unstable rev; use distrobox |
| cura-appimage broken | `Modules/Art/art.nix` | AppImage extract API change; commented out |
| Nyxt 4.0 not yet packaged | `Modules/Web/browsers.nix` | AppImage URL + hash TODO |
| sops secrets incomplete | `_secrets.yaml` | Need to add: google-app-password, habitica-api-key, habitica-user-id, borg-passphrase |
| Habitica hook not yet written | `~/.task/hooks/` | Script to POST task completions to Habitica API; blocked on habitica sops secrets |
| tbkeys not yet installed | Thunderbird | Manual Thunderbird extension install; no Nix packaging |
| sioyek inverse search → Emacs | `Modules/Knowledge/pdf.nix` | Legacy `emacsclient` command; replace with nvim equivalent when re-adding |
| CLAUDE.md references hjem + Tn-emacs | `CLAUDE.md` | Both no longer exist; stale documentation |
| 6 flake inputs removed | `flake.nix` | nixpkgs-stable, nix-index-database, home-manager, hyprland, lazyvim-nix, plover-flake — re-add as features are restored |
