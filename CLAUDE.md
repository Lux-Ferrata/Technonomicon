# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal NixOS system configuration ("Technonomicon") for two machines:
- **Akmon** — desktop with Nvidia GPU, Kinesis Advantage2 keyboard, runs bash
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

## Architecture

### Flake structure

The flake uses `flake-parts` + `import-tree` to auto-import all `.nix` files under `Modules/` and `Hosts/`. Each file contributes a `flake.nixosModules.<name>` output or a `flake.nixosConfigurations.<name>` output — no central module list needed.

### Module naming convention

All shared modules are prefixed `Tn-` (Technonomicon):
- `Tn-nix` — nix daemon settings, nh, nix-index/comma
- `Tn-desktop` — wayland/ewm, greetd, kanata, pipewire, fonts, dconf
- `Tn-emacs` — doom-emacs-unstraightened, dev tooling (LSPs, compilers)
- `Tn-shell` — xonsh, direnv, starship, core CLI tools
- `Tn-web-browsers`, `Tn-web-apps` — Brave + PWA desktop entries
- `Tn-network`, `Tn-sound`, `Tn-pdf`, `Tn-games`, `Tn-learning`, `Tn-art`, `Tn-utf`, `Tn-virtualization`

### Home management

Uses **hjem** (not home-manager) with the `hjem-impure` extension enabled for the `xin` user. Dotfiles are managed via `environment.etc` entries in modules (not hjem's file system).

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

### Custom packages

`Modules/Art/` contains local derivations for PureRef and Allusion (proprietary AppImage-style packages not in nixpkgs).

### Dev toolchains installed system-wide (via Tn-emacs)

Haskell (GHC + cabal + HLS), Python (pyright + ruff + black), Nix (nixfmt + nixd), C (gcc + clangd), Zig (zig + zls), BQN (cbqn), Guile, Racket, NASM, GForth, Verilog/VHDL (verilator + verible + ghdl).
