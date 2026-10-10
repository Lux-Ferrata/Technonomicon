# TODO

Open items from the Akmon services rollout (October 2026). Tick them off or
delete them as they're done.

## Waiting on a decision

- [ ] **Media layout.** All media is being reorganised; the current paths are
      scaffolding. Decide the new layout, then re-point:
  - Immich's external libraries (now `/srv/xin/Media` at `/mnt/media`,
    `Modules/Services/immich.nix`). Images actually live mostly in
    `Grimoire/Assets` and `Apocrypha/force-drawing` today.
  - Where Paperless, Karakeep and Takeout imports keep their files, if that
    should change.
- [ ] **Phase 5 photos** (after the layout):
  - `photos-push DIR|FILES… [--album NAME]`: manual upload to Google Photos via
    rclone (`gphotos:`). Never automatic.
  - `photos-pull-takeout ZIP…` on Akmon: Takeout → `immich-go` → Immich's own
    library. Zips land in `/srv/xin/takeout`, deleted after import.
  - The Google OAuth client already has (or needs) the Photos Library API
    enabled. Big imports can borrow the GPU with `gpu-lend`.

## Calendars

Google Calendar is home; Radicale only stages the generated deadline
calendars (`task-deadlines.nix` → `calendar-push.nix`).

- [x] Stale Radicale collections (`classes`, `office-hours`, an empty "Class
      Time") deleted 2026-10-09; the push carries only the two generated pairs.
- [ ] Kvasir: `~/.local/share/calendars` and `~/.local/share/vdirsyncer` are
      left from the retired khal sync and can go.

## Mail

- [ ] School/work account: once the provider is known, add it to Thunderbird
      (`Modules/Web/email.nix`) and to the archive (`tn.mailArchive.accounts`,
      `Modules/Services/mail-archive.nix`). Microsoft 365 / Google schools
      usually need OAuth2 (sasl-xoauth2 + oama) instead of a password.

## Client setup (manual, any time)

- [ ] Phone: accept the Grimoire share in Syncthing-Fork, open it in Obsidian.
- [ ] Phone: Paperless and Karakeep apps (`docs.` / `keep.ironshark.org`).
- [ ] LanguageTool in Obsidian and the Brave extension → `https://lt.ironshark.org`.
- [ ] Karakeep: make the first (admin) account, add the Brave extension.
- [ ] Immich: first login, then Administration → External Libraries.
- [x] Google Drive: run `gdrive-login` once on Kvasir.
- [ ] Delete the old Web-type OAuth client in the Google console.

## Round 3 setup (manual)

- [ ] Vaultwarden (`vault.ironshark.org`): create the account, import the
      newest `/srv/backup/bitwarden/` export (export password: sops
      `bitwarden-export-password`), then set `SIGNUPS_ALLOWED = false`
      (`Modules/Services/vaultwarden.nix`).
- [ ] Jellyfin (`media.`), Audiobookshelf (`audiobooks.`), Pinchflat (`yt.`):
      first-run admin accounts, then libraries under `/srv/media/...`
      (placeholder layout). Jellyfin: Dashboard > Playback > NVIDIA NVENC.
- [ ] Phone: Jellyfin, Audiobookshelf, and a Miniflux reader (Read You /
      Capy Reader) on `rss.ironshark.org`.
- [ ] Torrent VPN: when the Mullvad exit node is on, set
      `tn.torrent.vpnInterface = "tailscale0"`.
- [ ] DAS: once bought, create the `bulk` pool and set `tn.nas.bulkPool`.
- [ ] Thunderbird: drop the Feeds account once Miniflux has taken over.
- [ ] AstraDraw (`draw.`, launcher "Flowchart"): first login as `xin`,
      password sops `astradraw-admin-password`.

## Theme: apps still outside the palette

The palette lives in `Modules/Core/_palette.nix`: base16 plus roles (`bg
surface sel dim punct plain comment string const def accent error warn …`).
New consumers `import ./_palette.nix` and use the roles, never copied hex
values. The rules are the same everywhere:
- Only comments, strings, constants and definitions get color.
- Punctuation is grey.
- The row being chosen is solid blue with dark text.

- [ ] **Obsidian:** a CSS snippet, or a small theme, from the roles:
  - `--background-primary`/`-secondary` from bg/surface, `--text-normal` plain, `--text-muted` dim, `--interactive-accent` blue.
  - Code blocks through CodeMirror's classes: `.cm-comment` yellow, `.cm-string` green, `.cm-number`/`.cm-atom` purple, `.cm-def` blue, keywords plain.

  Create it in Obsidian (Appearance → CSS snippets) or with `obsidian-cli`, never with a shell write into `~/Grimoire`. A home-manager symlink in the vault would sync to the phone and Akmon.
- [ ] **Starship prompt** (`Modules/Core/shell.nix`): the hardcoded `#539bf5`, `#768390` and nord green become ANSI names (`blue`, `bright-black`, `green`). The prompt then follows Ghostty's palette on both hosts (Akmon has no Tn-theme).
- [ ] **delta**, and lazygit through it (`shell.nix`):
  - Build a bat `.tmTheme` from the same TextMate rules as VSCodium (`programs.bat.themes.tn`), then set delta's `syntax-theme = "tn"`.
  - `plus-style`/`minus-style` use green/red-tinted backgrounds.
  - The built-in `ansi` theme would color keywords.
- [ ] **fzf** (fzf.fish, `tn-snip`, the `*-menu` functions): `FZF_DEFAULT_OPTS --color=bg+:<blue>,fg+:<bg>,hl:<blue>,hl+:<bg>,pointer:<blue>,info:<dim>,border:<border>`, so the chosen row looks as it does everywhere else.
- [ ] **sioyek** (`Modules/Knowledge/pdf.nix`): `dark_mode_background_color` becomes bg as floats (`0.094 0.102 0.106`), plus `custom_background_color`/`custom_text_color` and the highlight colors.
- [ ] **fcitx5 candidate window** (`Modules/Core/utf.nix`, now `fcitx5-nord`): a `tn` classicui theme (`~/.local/share/fcitx5/themes/tn/theme.conf`) generated from the palette, with `Theme=tn`.
- [ ] **GTK/libadwaita apps** (Nemo, file pickers, portals): `gtk.gtk3.extraCss`/`gtk4.extraCss` with `@define-color window_bg_color`, `view_bg_color`, `headerbar_bg_color`, `accent_bg_color` and `accent_color` from the roles. Qt keeps following `adwaita-dark` unless it moves to qt6ct with a palette.
- [ ] **Linux console and tuigreet** (both hosts): `console.colors` set to the 16 ANSI colors from `_palette.nix`.
- [ ] **Brave's own UI** (tabs, toolbar): Chromium's `BrowserThemeColor` policy set to bg. Add only that key; page colors stay Dark Reader's job.
- [ ] **Akmon's btop** (`Modules/Core/server-usage.nix`, `color_theme = "nord"`): a `tn` btop theme from `_palette.nix`, like Kvasir's.
- [ ] **yazi** (Tn-neovim): `programs.yazi.theme` from the roles, with the chosen row solid blue.
- [ ] **OpenHabitTracker:** pick its closest dark theme in Settings (there's no config file to set).
- Discord, Thunderbird, Anki and Zotero keep their built-in dark themes.

## Later

- [ ] Immich machine learning on the GPU (CUDA build, compiled on Akmon) if the
      library grows enough for it to matter.
- [ ] Karakeep: turn off sign-ups once the account exists (`DISABLE_SIGNUPS`).
- [ ] Hydrus, if exact tag-based image search turns out to be missing.
- [ ] BBDB-style people hub: Google Contacts -> Radicale (CardDAV, vdirsyncer
      google_contacts); a nightly generator keeps Obsidian `People/` notes with
      contact fields plus a marked, generated block of email threads (archive
      search, `mid:` links into Thunderbird) and calendar events. Must respect
      the vault rule (write via the Obsidian CLI / marked blocks only).

## Monitoring follow-ups

- [ ] **Around 2026-10-14:** VictoriaMetrics has a week of data. Remove the
      `tn-usage-log` CSV logger (`Modules/Core/server-usage.nix`; keep `aku`)
      and stop feeding `usage.txt` to the weekly summary.

## Queue (after the monitoring stack)

- [ ] **Office suite (Tn-office, `Modules/Services/office.nix`).** OpenCloud +
      Collabora at `https://office.ironshark.org`. After the first deploy: log
      in as `admin` (sops `opencloud-admin-password`), create your own user,
      and install the OpenCloud desktop/phone clients if you want sync.
