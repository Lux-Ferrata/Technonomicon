# Technonomicon

Personal NixOS configuration for two machines that work as one:

| Host | Hardware | Role |
|---|---|---|
| **Kvasir** | ThinkPad T480s (i7-8650U, UHD 620, 40 GB) | The laptop and only desktop: Hyprland, editors, browser. Everything is authored here. |
| **Akmon** | Headless server, Nvidia GPU, ZFS | Build host, Forgejo, local LLMs, every `*.ironshark.org` service, and the remote half of the dev environment. Wipes `/` and `~` on every boot (impermanence; state lives in `/persist` and `/srv`). |

The goal is that working on Akmon (a VSCodium remote window, `ak`, `rb`) feels the same as working locally on Kvasir. Same shell, same history, same directory jumps, same git identity.

## Layout

The flake uses `flake-parts` + `import-tree`: every `.nix` file under `Modules/` and `Hosts/` is imported automatically and contributes a `flake.nixosModules.Tn-<name>` or a `nixosConfigurations.<Host>`. There is no central module list; each host picks the `Tn-*` modules it wants.

```
Hosts/<Host>/          host definitions (Akmon: disko, impermanence, auto-upgrade)
Modules/Core/          desktop, shell, editors, dev client/host, server, monitoring
Modules/Services/      Akmon's web services (one Tn-<svc> per file)
Modules/Knowledge/     learning, science, PDF, scanning, Obsidian
Modules/Web/           browser, web apps, mail, chat, games, Google Drive
Modules/Art/           creative tools (a local Allusion derivation)
bin/                   scripts wrapped by modules (tn-snip, tn-show-keybindings)
agents/                overnight agent runner + lagent (local-model helper)
ci/                    nightly curation / weekly upgrade job (Forgejo Actions)
snippets/<lang>.json   personal code snippets (VSCodium + LazyVim + tn-snip)
_secrets.yaml          sops-nix secrets (age)
TODO.md                open items from the Akmon rollout
```

Files starting with `_` are sourced by a module, not imported on their own.

## Building and deploying

```bash
tn-check <akmon|kvasir|all>      # build without activating (on Akmon; falls back to local)
deploy   <akmon|kvasir|all>      # build on Akmon + switch; asks for sudo once
nh os switch                     # plain local switch, if ever needed
```

`deploy all` does Akmon first and skips Kvasir if Akmon fails. Akmon signs its builds, so Kvasir pulls them straight from its cache.

**Branches:** `working` gets everything as it happens, including auto-commits. `main` is written only by the nightly bot (`ci/nightly.sh`): it is a curated, readable changelog of `working`, and no machine follows it. On Wednesdays the job also runs `nix flake update`, fixes breakage, and mails a summary. Akmon auto-upgrades from `working` on Wednesdays at 05:30. The repo lives on Forgejo (`git.ironshark.org`) and is push-mirrored to GitHub.

## Day-to-day commands (Kvasir)

| Command | What it does |
|---|---|
| `eo [path]` | Open in VSCodium: on Akmon over Remote-SSH when the project is synced there, otherwise locally |
| `eol [path]` | Same, always local |
| `ak [name]` | Persistent shell on Akmon (shpool), named after the current project; reconnects by itself |
| `rb <cmd>` | Run one command on Akmon in the same directory, with the project's direnv env |
| `aku` | Akmon's load (btop); `aku -s` snapshot, `aku --week` digest |
| `t <dir>` / `ti` | zoxide jump / interactive |
| `send <files>` | Taildrop to the phone |
| `overnight-add "task" [project]` | Queue work for the overnight agents; `overnight-now` starts a run |
| `lagent ask/read/search/code` | Hand work to the local models on Akmon (see below) |
| `grimoire-commit` | Named commit of the Obsidian vault (its git lives on Akmon) |
| `paperless-add FILE…`, `scan --paperless` | Documents into Paperless |
| `stt` / `tts` | Speech to text (Akmon GPU or local CPU) / text to speech |

Akmon has the same shell, plus its own versions of `rb`, `ak` and `overnight-now` that run in place.

## Remote = local

- **Files:** Syncthing keeps `~/Projects` identical on both machines (two-way, `.git` included). The exceptions are build outputs (`target/`, `.venv/`, `node_modules/`, `result`, …), which each machine keeps for itself, and **Technonomicon**, which moves through git + Forgejo instead. The Grimoire vault syncs too; its git history is owned by Akmon.
- **Shell:** both hosts import `Tn-shell`: fish, starship, atuin, carapace, zoxide, direnv, git.
- **History:** atuin syncs through a self-hosted server on Akmon (`atuin.ironshark.org`, end-to-end encrypted), so Ctrl-R shows one history.
- **Directory jumps:** `zoxide-sync` (a Kvasir timer, every 15 min) copies directories each side lacks to the other.
- **Git:** pushes from Akmon use Kvasir's forwarded SSH agent. Commits are signed with the shared ssh key from sops.
- **Dev shells:** every project has a flake `devShells.default` + `.envrc` (`use flake`). Kvasir's `prewarm-devshells` timer realises them from Akmon's cache, so they work offline.

## Editors

**VSCodium** is the primary editor (on trial over LazyVim, which stays fully set up and is `$EDITOR`):
- Remote windows on Akmon via Open Remote-SSH. Akmon's server gets the same extensions from Open VSX.
- VSCodeVim with **flash** on `s` (labels follow every keystroke), Harpoon on `<leader>h/H/1-5`, save on Esc.
- **basedpyright** for Python: pyright's engine plus inlay hints, builtin docstrings and better auto-imports. Pylance won't run on VSCodium. Also ruff/black, clangd, rust-analyzer, nixd, LaTeX Workshop, LTeX+ (against Akmon's LanguageTool), and llama-vscode completion from the local models.
- **High-contrast "Nord Alabaster"** syntax theme, shared with both nvims (`_nord-alabaster.lua`). It's Tonsky-style: plain text is nord6 on a deeper `#1E222A`, and only comments (gold), strings, constants and *definitions* get colour. Every colour is at least 8:1.

**Snippets** live in `snippets/<language>.json` (VS Code format, plain JSON). VSCodium's snippets folder is a live symlink to it, so "Configure Snippets" edits the repo. LazyVim loads the same files. They are added by hand, as needed.

**Snippet finder** (`Super+Shift+H`, `bin/tn-snip`) is fzf over the Obsidian Latex Suite math snippets and every `snippets/<lang>.json`:
- Search by trigger, description, the LaTeX rendered to Unicode (∫, α, √), or English words.
- The preview shows the full skeleton with its tabstops.
- It opens on math from Obsidian, and on the current file's language from VSCodium.

## Desktop (Kvasir)

Hyprland (Lua config, permanent scrolling layout), Quickshell bar, Ghostty, greetd. Some keys:

| Key | Action |
|---|---|
| `Super+Space` | App launcher (fuzzel) |
| `Super+B` / `Super+Shift+B` / `Super+Alt+B` | Window picker: all windows / this workspace / pull one here from another workspace (fuzzel, fuzzy) |
| `Super+Shift+H` | Snippet finder |
| `Super+X` / `Super+Shift+X` | Clipboard history / quick-paste personal values |
| `Super+G` / `Super+Shift+G` | Keyboard pointer (wl-kbptr) |
| `F4` (VSCodium) | Toggle the terminal |

**Keyboard:** kanata with Colemak-DH, home-row mods (RSTN / NEIO), a nav layer on Space/Backspace hold, a numpad layer on Escape hold, and one-shot modifiers (`_kanata.kbd`). Akmon's console runs a minimal version.

**Brave:**
- Wayland and VA-API hardware video decode. `--enable/--disable-features` must repeat nixpkgs' lists, see the comment in `browsers.nix`.
- enhanced-h264ify, so YouTube serves H.264 (Kaby Lake can't decode AV1 in hardware).
- Memory Saver on.
- SearXNG as the default search engine.
- PWAs for Gmail, Calendar, etc. (`web-apps.nix`).

## Akmon services

Every service is `<name>.ironshark.org`: an A record pointing at Akmon's tailnet IP, so tailnet-only. One wildcard cert covers them all (DNS-01 via Cloudflare), with nginx in front and one shared Postgres (`Modules/Services/web.nix`). A new service is one module that sets `tn.web.vhosts.<name>`.

| Name | Service |
|---|---|
| `git.` | Forgejo + Actions runner (repo home, CI, agent task queue) |
| `search.` | SearXNG: ~90 engines (web, reference, science, dev); Brave's default |
| `atuin.` | Shell history sync |
| `rss.` | Miniflux (phone: Capy Reader; Kvasir: NewsFlash) |
| `lt.` | LanguageTool (VSCodium LTeX+, Obsidian, Brave) |
| `docs.` | Paperless-ngx |
| `photos.` | Immich (search by description, faces, text) |
| `keep.` | Karakeep (bookmarks with archives, tags from the local model) |
| `cal.` | Radicale + InfCloud; staging for calendars pushed to Google Calendar |
| `dav.` | WebDAV (Zotero attachments, Super Productivity sync) |
| `vault.` | Vaultwarden (nightly backup of the Bitwarden cloud vault) |
| `office.` | OpenCloud + Collabora |
| `media.`, `audiobooks.`, `yt.`, `torrent.` | Media stack: Jellyfin, Audiobookshelf, Pinchflat, qBittorrent (placeholder layout, see TODO.md) |
| `mail.` | IMAP of the mail archive (Thunderbird) |
| `admin.` | Cockpit (VMs, containers) |
| `sync.` | Syncthing GUI (Akmon is the hub) |
| `metrics.` | Grafana |

Also on Akmon:
- a mail archive (mbsync, never deletes)
- Super Productivity deadlines → Radicale → Google Calendar
- Grimoire snapshots every 5 min
- a NAS (Samba) and VMs (libvirt)
- `gpu-lend`, which hands the GPU to a big job

**Monitoring is for Claude, not dashboards:**
- VictoriaMetrics + vmalert + exporters, with alerts filed as deduplicated Forgejo issues (`tn-issue`).
- A 05:40 Claude health review, and digest mails at 06:00.

**Local AI:**
- llama.cpp on the GPU: a small always-on completion model for editors (`:8012`), and Qwen3-Coder-30B-A3B for chat, loaded on demand (`:8011`).
- When Akmon is away, Kvasir falls back to a CPU model.
- Each night the **overnight agents** (Claude supervising the local models) work through Forgejo issues labelled `overnight` and leave branches or PRs. They delegate to `lagent`:
  - `lagent ask` answers from the local model.
  - `lagent read FILE-OR-URL [question]` reads PDFs, web pages, DOCX or EPUB in parts with page references.
  - `lagent search` returns SearXNG results.
  - `lagent code` makes an aider edit.

## Secrets

sops-nix with age keys (`.sops.yaml`), all in `_secrets.yaml`. Machines decrypt with their SSH host key. Edit with `sops _secrets.yaml`. Service passwords are generated straight into it.

## Post-install steps

### Kvasir

- `direnv allow` in each new project (Akmon trusts `~/Projects` automatically).
- `gdrive-login` once, for the rclone Google Drive mount.
- NewsFlash → Miniflux: an API token in NewsFlash's settings (imperative).
- atuin: `atuin register` on one machine, then `atuin login -k <key from atuin key>` on the other. The account password is sops `atuin-password`.

### Zotero: move data out of home root

Zotero defaults to `~/Zotero`. To move it to a hidden directory:

1. Open Zotero → **Edit → Preferences → Advanced → Files and Folders**
2. Under **Data Directory Location**, select **Custom** and set it to `~/.zotero`
3. Zotero will offer to move existing data. Accept.
4. Delete the old directory: `rm -rf ~/Zotero`

### Zotero: Better BibTeX + Grimoire library export

The Grimoire vault's literature layer (Citation plugin + blog citations) feeds off a single auto-updating BibLaTeX file. Zotero 8+ has native citation keys; Better BibTeX (BBT) is here for the *keep-updated `.bib` export*.

1. Install **Better BibTeX v9.x** (supports Zotero 8/9): download the `.xpi` from <https://github.com/retorquere/zotero-better-bibtex/releases>, then Zotero → **Tools → Plugins → gear → Install Plugin From File** → pick the `.xpi`. Restart Zotero.
2. Ensure the target dir exists: `mkdir -p ~/.local/share/zotero`
3. In Zotero, right-click **My Library** → **Export Library…**
   - Format: **Better BibLaTeX**
   - Check **Keep updated**
   - Save as `~/.local/share/zotero/grimoire-library.bib`
4. Confirm **Settings → Better BibTeX → Automatic export = On change** so the file self-updates. The Obsidian Citation plugin and the blog's `import-from-grimoire.py` both point at this exact path.

Attachments sync over WebDAV: Zotero → Settings → Sync → Files → WebDAV, `dav.ironshark.org`, user `zotero`.

## Phone

- Tailscale (+ Mullvad) always on; Taildrop with `send`
- Syncthing-Fork: the Grimoire share, opened in Obsidian
- Super Productivity (WebDAV sync to Akmon)
- Capy Reader → Miniflux
- DAVx5 → `cal.ironshark.org`; Paperless and Karakeep apps

## Roadmap

Open items from the services rollout are in [`TODO.md`](TODO.md).

### Major changes
- [ ] Kvasir: BTRFS or ZFS, impermanence + tmpfs (done on Akmon)
- [ ] Full disk encryption
- [ ] Reference boot image
- [x] wl-kbptr installed and bound (`Super+G`). Re-check whether upstream has released `--drag`.
- [x] Calendar: Google Calendar is home; Radicale only stages generated calendars (Super Productivity deadlines) that are pushed to Google. This replaces the khal plan.

### Not sure if it is worth actually making these changes
- [ ] Switch Phone and Tablet to Graphene and Lineage OS?
- [ ] Move website and personal code to Codeberg, with GitHub mirror? (Forgejo on Akmon is now the primary home)
- [ ] nix-on-droid?
- [ ] Aurora (Android app store)
- [ ] Switch to the Proton suite instead of Google Workspace?

### Homelab
- [ ] Hydrus picture and gif server (ML image recognition, search, and tagging); deferred
- [x] LanguageTool server for Obsidian grammar and spell checking (`lt.ironshark.org`)
- [x] Super Productivity with sync to Akmon
- [ ] Super Productivity time tracking
