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

Deploying goes through `deploy` (Tn-dev-client) on Kvasir. It asks for the sudo password up front, so xin runs it:

```bash
deploy akmon     # evaluate here, build on Akmon, switch Akmon over ssh
deploy kvasir    # build on Akmon (locally when it's away), switch Kvasir
deploy all       # Akmon first; Kvasir only if Akmon succeeded
```

Never switch a machine to the other's configuration: `nh os switch --hostname Akmon` run on Kvasir would do exactly that. A plain `nh os switch` means "this machine" (Kvasir's flake path is this repo; Akmon's is the Forgejo `working` branch). `nixos-rebuild` is blocked by a hook.

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

All shared modules are prefixed `Tn-` (Technonomicon); each host picks the ones it wants.

**Core/**
- `Tn-desktop` — greetd, kanata, PipeWire, fonts, portals, GTK/Qt theme, Plover, Steam
- `Tn-hyprland` — Hyprland (Lua config, scrolling layout), Quickshell bar and notifications, hypridle/hyprlock, pickers and keybindings, Ghostty
- `Tn-neovim` — LazyVim, VSCodium (primary editor, on trial) and `eo`, Yazi
- `Tn-devtools` — compilers, language servers, formatters, debuggers, aider (both hosts)
- `Tn-shell` — fish, xonsh (scripting only), atuin, carapace, zoxide (`t`/`ti`), direnv, starship, git, CLI tools (both hosts)
- `Tn-network`, `Tn-nix` (nix settings, nh, nix-index), `Tn-sound`, `Tn-theme`, `Tn-utf` (locales, fcitx5), `Tn-print`, `Tn-virtualization`, `Tn-user-settings` (the `tn.*` options)
- `Tn-dev-client` / `Tn-dev-host` — "Akmon is the dev box": `eo`, `rb`, `ak`, Syncthing, LLM endpoints with offline fallbacks, `deploy`, `tn-check`
- `Tn-build-client` / `Tn-build-host` — remote builds and Akmon's signed cache (harmonia)
- `Tn-server`, `Tn-server-*`, `Tn-console-kanata` — Akmon's base: tailscale and sshd, mail relay, alerts (`tn-issue`), metrics, report mails, Claude's health review, `aku`, a rescue nvim, the console keyboard
- `Tn-forgejo` (git + CI runner), `Tn-overnight` (overnight agents)

**Services/** — Akmon's web services. Each sets `tn.web.vhosts.<name>`, which gives it `https://<name>.ironshark.org` (tailnet-only) and a DNS record. `Tn-server-web` provides nginx, the wildcard cert and the shared Postgres; the rest are one module per service (Grimoire, LanguageTool, Radicale + calendar push + task deadlines, WebDAV, Paperless, Immich, Karakeep, mail archive, Miniflux, Atuin, SearXNG, Vaultwarden, media, NAS, torrent, hosting, office, AstraDraw, OpenHabitTracker).

**Knowledge/**
- `Tn-learning` — hledger, fava, beancount, gnucash, visidata, anki, zotero (pinned input), foliate, rnote
- `Tn-mind` — Obsidian, OpenHabitTracker (Flathub), pomodoro
- `Tn-vikunja` — Kvasir's local Vikunja (tasks, offline), tailnet access, backup to Akmon
- `Tn-pdf` — sioyek (inverse search into VSCodium)
- `Tn-science` — julia, R, octave, maxima, gnuplot, gap, sage, lean4, quarto, geogebra
- `Tn-scan` — scanner, `scan` / `multi-scan`, `paperless-add`
- `Tn-provenance` — signed, timestamped snapshots of flagged Grimoire notes

**Web/**
- `Tn-web-browsers` — Brave (wrapper, flags, policy)
- `Tn-web-apps` — PWA launchers (icons vendored in `Modules/Web/icons/`)
- `Tn-communication` — Discord (flatpak), NewsFlash
- `Tn-email` — Thunderbird (mail and the Google calendars), aerc/notmuch/isync/msmtp, `calendar-push-login`
- `Tn-gdrive` — rclone `gdrive:` and the `~/GDrive` mount
- `Tn-games` — games

**Art/**
- `Tn-art` — creative tools; a local Allusion derivation (AppImage, not in nixpkgs)

Akmon's own files under `Hosts/Akmon/`: disko layout, impermanence (anything not under `/persist`, `/nix` or a data pool is gone after a reboot) and the weekly auto-upgrade.

### Home management

Uses **home-manager** for the `xin` user, configured inline within each module via `home-manager.users.xin = { ... }`. Dotfiles that live outside home-manager are managed via `environment.etc` entries.

### Secrets

Encrypted with **sops-nix** + age keys. The secrets file is `_secrets.yaml` at the repo root. Three age keys are configured in `.sops.yaml`. Each host decrypts with its SSH host key (Akmon's lives in `/persist/etc/ssh/`, since its root is wiped on boot). Service passwords are generated straight into the file.

To edit secrets:
```bash
sops _secrets.yaml
```

### Config files

Files prefixed with `_` are sourced by a module (configs, scripts, helpers), not imported on their own:
- `_kanata.kbd` / `_kanata-console.kbd` — Kvasir's keyboard layout / Akmon's console layout
- `_sync.nix` (the whole Syncthing topology), `_models.nix` (pinned LLM weights), `_llama-ondemand.nix` (wake-on-request servers)
- `_tn-*.sh` / `_tn-*.py` — monitoring, report and usage scripts; `_palette.nix` — the colours (base16 scheme `tn` + roles) for the desktop, VSCodium and nvim; `_tn-nvim.lua` — nvim's colours from it
- `_fcitx5-config`, `_gromit-mpx.cfg/.ini` — input method / screen annotation configs

### Kanata keyboard layout

The layout is Colemak-DH with:
- Home-row mods (RSTN / NEIO) — tap for letter, hold for Shift/Meta/Alt/Ctrl
- Space/Backspace → nav layer on hold (arrows, home/end/pgup/pgdn, word jump)
- Escape → num layer on hold (numpad layout on HJKL cluster)
- One-shot modifiers on modifier keys (tap = one-shot, hold = sticky)

### Dev toolchains installed system-wide (via Tn-devtools, both hosts)

Haskell (GHC + cabal + HLS), Python (pyright + ruff + black), Nix (nixfmt + nixd), C/C++ (clang-tools, gcc, cmake, ninja, bear), Rust, Zig (zig + zls), BQN (cbqn), Guile, Racket, NASM, GForth, Verilog/VHDL (verilator + verible + ghdl), TypeScript (ts-ls + prettier), LaTeX (texlive + texlab), Typst (typst + tinymist), competitive programming (ACL headers, `oj`).
