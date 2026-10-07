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

## Calendar push to Google (Phase 2)

The Google login is done; the token is on Akmon at
`/srv/xin/.calendar-push/google-token`.

- [ ] Create the calendars in InfCloud (`https://cal.ironshark.org/infcloud/`).
- [ ] Create an empty Google calendar for each one to publish.
- [ ] Pair them in `tn.calendarPush.calendars`
      (`Modules/Services/calendar-push.nix`). Google IDs: `calendar-push-login`,
      or ask Claude to look them up on Akmon.

## Mail

- [ ] School/work account: once the provider is known, add it to Thunderbird
      (`Modules/Web/email.nix`) and to the archive (`tn.mailArchive.accounts`,
      `Modules/Services/mail-archive.nix`). Microsoft 365 / Google schools
      usually need OAuth2 (sasl-xoauth2 + oama) instead of a password.
- [ ] Thunderbird calendars: File > New > Calendar > On the Network,
      `https://cal.ironshark.org/` (Radicale) and Google.

## Client setup (manual, any time)

- [ ] Phone: accept the Grimoire share in Syncthing-Fork, open it in Obsidian.
- [ ] Phone: DAVx5 → `https://cal.ironshark.org/` (user `xin`, sops
      `radicale-password`) for calendars; Vikunja app → `https://tasks.ironshark.org`.
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
