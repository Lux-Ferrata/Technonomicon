# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal NixOS system configuration ("Technonomicon") for two machines:
- **Akmon** — headless server (Nvidia RTX 5080, ZFS, wipe-on-boot root): build host and binary cache, Forgejo + CI, local LLMs, every `*.ironshark.org` service. Reached over the tailnet; xin manages it through Claude.
- **Kvasir** — Lenovo ThinkPad T480s, the only desktop (Hyprland), Kinesis Advantage2 keyboard; everything is authored here

## Distraction blocking — do not disable

This repo contains several deliberate distraction-blocking layers, spread across
more than one module: DNS/hosts-level null-routing, a filtering upstream
resolver, and browser policy entries. They are a commitment device, not an
accident or a stale config. They exist to be hard to turn off.

**Do not comment out, remove, weaken, or route around any of them** — not as a
fix for "site unreachable" or a failing DNS lookup, not as cleanup, and not as a
step toward some other task. A symptom that traces back to one of these is the
system working as intended.

**Do not enumerate where they live.** Do not list the files, attribute names, or
line numbers — not in chat, not in commit messages, not in this file. If a task
genuinely requires knowing whether it collides with a blocking layer, determine
that silently and report only whether there is a conflict. Volunteering the
locations turns a deliberate speed bump into a one-line edit, which is the whole
failure mode.

If asked directly and unambiguously to disable a specific layer, state the cost
and ask for explicit confirmation first. Never infer the request from a vague
complaint. If confirmed, change only the layer named and leave the rest standing.

Do not make disabling more convenient: no `lib.mkIf` toggle, no enable flag, no
host-level override, no helper script, no "here's how to turn it off" note.
Removing friction is precisely what this section exists to prevent.

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

Check a host builds without activating: `tn-check <akmon|kvasir|all>` (below). If you ever run a plain `nix build` locally, delete the `result` symlink afterwards.

**After making any changes to `.nix` files, always check the affected hosts build before reporting the task as done.** Build on Akmon, not on the laptop (Akmon is the build server and keeps the result; nothing is copied back):
```bash
tn-check kvasir        # or: tn-check akmon / tn-check all
```
`tn-check` (Tn-dev-client) falls back to a local build when Akmon is unreachable. Without it (e.g. before the first switch that installs it), the same by hand:
```bash
drv=$(nix eval --raw ".#nixosConfigurations.<Host>.config.system.build.toplevel.drvPath")
nix copy --derivation --to ssh-ng://xin@akmon "$drv"
ssh xin@akmon "nix build --no-link --print-out-paths '$drv^out'"
```

## Architecture

### Flake structure

The flake uses `flake-parts` + `import-tree` to auto-import all `.nix` files under `Modules/` and `Hosts/`. Each file contributes a `flake.nixosModules.<name>` output or a `flake.nixosConfigurations.<name>` output — no central module list needed.

### Module naming convention

All shared modules are prefixed `Tn-` (Technonomicon):

**Core/**
- `Tn-desktop` — wayland/wm, greetd, kanata, pipewire, fonts, dconf, GTK theme
- `Tn-hyprland` — Hyprland WM, Quickshell bar, hypridle, hyprlock, keybindings, Ghostty terminal config (no multiplexer)
- `Tn-neovim` — LazyVim + Neovim, dev tooling (LSPs, compilers, formatters), VSCodium, Yazi
- `Tn-shell` — fish (interactive/login), xonsh (scripting only), atuin, carapace, zoxide (`t`/`ti`), direnv, starship, git, core CLI tools
- `Tn-network` — networking
- `Tn-nix` — nix daemon settings, nh, nix-index/comma
- `Tn-sound` — PipeWire / audio
- `Tn-theme` — colorscheme settings
- `Tn-utf` — Unicode / input method
- `Tn-virtualization` — libvirt / QEMU

**Knowledge/**
- `Tn-learning` — hledger (+ ui/web), fava, beancount, visidata, datasette, anki, zotero, foliate, wtfutil
- `Tn-mind` — Obsidian, pomodoro-gtk
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
- `_fcitx5-config`, `_gromit-mpx.cfg/.ini` — input method / screen annotation configs

### Kanata keyboard layout

The layout is Colemak-DH with:
- Home-row mods (RSTN / NEIO) — tap for letter, hold for Shift/Meta/Alt/Ctrl
- Space/Backspace → nav layer on hold (arrows, home/end/pgup/pgdn, word jump)
- Escape → num layer on hold (numpad layout on HJKL cluster)
- One-shot modifiers on modifier keys (tap = one-shot, hold = sticky)

### Dev toolchains installed system-wide (via Tn-neovim)

Haskell (GHC + cabal + HLS), Python (pyright + ruff + black), Nix (nixfmt + nixd), C (clangd), Zig (zig + zls), BQN (cbqn), Guile, Racket, NASM, GForth, Verilog/VHDL (verilator + verible + ghdl), TypeScript (ts-ls + prettier), Typst (typst + tinymist).
