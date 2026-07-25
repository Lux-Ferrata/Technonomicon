# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal NixOS system configuration ("Technonomicon") for two machines:
- **Akmon** — desktop with Nvidia GPU, Kinesis Advantage2 keyboard
- **Kvasir** — Lenovo ThinkPad T480s laptop, runs xonsh

## Building and deploying

`nh` is configured system-wide with the flake path pointing to this repo, so all rebuilds use the shorthand:

```bash
# Rebuild and switch (preferred — handles diffs, GC, etc.)
nh os switch

# Rebuild for a specific host
nh os switch --hostname Akmon
nh os switch --hostname Kvasir

# Test without switching boot entry
nh os test

# Build without activating
nh os build
```

Raw nixos-rebuild equivalents (if nh is unavailable):
```bash
sudo nixos-rebuild switch --flake /home/xin/Projects/Technonomicon#Akmon
sudo nixos-rebuild switch --flake /home/xin/Projects/Technonomicon#Kvasir
```

Check a flake builds without activating:
```bash
nix build .#nixosConfigurations.Akmon.config.system.build.toplevel
```

After any `nix build` test, always delete the resulting `result` symlink:
```bash
rm result
```

**After making any changes to `.nix` files, always run a build to confirm correctness before reporting the task as done:**
```bash
nix build .#nixosConfigurations.Kvasir.config.system.build.toplevel && rm result
```

## Architecture

### Flake structure

The flake uses `flake-parts` + `import-tree` to auto-import all `.nix` files under `Modules/` and `Hosts/`. Each file contributes a `flake.nixosModules.<name>` output or a `flake.nixosConfigurations.<name>` output — no central module list needed.

### Module naming convention

All shared modules are prefixed `Tn-` (Technonomicon):

**Core/**
- `Tn-desktop` — wayland/wm, greetd, kanata, pipewire, fonts, dconf, GTK theme
- `Tn-hyprland` — Hyprland WM, Quickshell bar, hypridle, hyprlock, keybindings, Ghostty terminal config
- `Tn-neovim` — LazyVim + Neovim, dev tooling (LSPs, compilers, formatters), VSCodium, Zellij, Yazi
- `Tn-shell` — xonsh, direnv, starship, git, core CLI tools
- `Tn-network` — networking
- `Tn-nix` — nix daemon settings, nh, nix-index/comma
- `Tn-sound` — PipeWire / audio
- `Tn-theme` — colorscheme settings
- `Tn-utf` — Unicode / input method
- `Tn-virtualization` — libvirt / QEMU

**Knowledge/**
- `Tn-learning` — hledger (+ ui/web), fava, beancount, visidata, datasette, anki, zotero, foliate, wtfutil
- `Tn-mind` — Obsidian, taskwarrior, timewarrior, pomodoro-gtk
- `Tn-pdf` — sioyek (PDF viewer with inverse search to Neovim)
- `Tn-science` — julia, R, octave, maxima, gnuplot, gap, sage, lean4, quarto

**Web/**
- `Tn-web-browsers` — Brave
- `Tn-web-apps` — PWA desktop entries (Gmail, Calendar, etc.)
- `Tn-communication` — Discord
- `Tn-email` — aerc, notmuch, isync, msmtp, khal, vdirsyncer, calcurse
- `Tn-games` — gaming tools

**Art/**
- `Tn-art` — creative tools; contains local derivations for PureRef and Allusion (proprietary AppImage-style packages not in nixpkgs)

### Home management

Uses **home-manager** for the `xin` user, configured inline within each module via `home-manager.users.xin = { ... }`. Dotfiles that live outside home-manager are managed via `environment.etc` entries.

### Secrets

Encrypted with **sops-nix** + age keys. The secrets file is `_secrets.yaml` at the repo root. Three age keys are configured in `.sops.yaml`. The SSH host key at `/etc/ssh/ssh_host_ed25519_key` is used for decryption.

To edit secrets:
```bash
sops _secrets.yaml
```

### Config files

Files prefixed with `_` are config files sourced directly into modules (not installed separately):
- `_kanata.kbd` — keyboard remapping (Colemak-DH + home-row mods + nav/num layers)
- `_config.xsh` — xonsh shell config
- `_gitconfig` — global git config
- `_fcitx5-config`, `_gromit-mpx.cfg/.ini` — input method / screen annotation configs

### Kanata keyboard layout

The layout is Colemak-DH with:
- Home-row mods (RSTN / NEIO) — tap for letter, hold for Shift/Meta/Alt/Ctrl
- Space/Backspace → nav layer on hold (arrows, home/end/pgup/pgdn, word jump)
- Escape → num layer on hold (numpad layout on HJKL cluster)
- One-shot modifiers on modifier keys (tap = one-shot, hold = sticky)

### Dev toolchains installed system-wide (via Tn-neovim)

Haskell (GHC + cabal + HLS), Python (pyright + ruff + black), Nix (nixfmt + nixd), C (clangd), Zig (zig + zls), BQN (cbqn), Guile, Racket, NASM, GForth, Verilog/VHDL (verilator + verible + ghdl), TypeScript (ts-ls + prettier), Typst (typst + tinymist).
