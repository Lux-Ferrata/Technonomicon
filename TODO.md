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

## Client setup (manual, any time)

- [ ] Phone: accept the Grimoire share in Syncthing-Fork, open it in Obsidian.
- [ ] Phone: DAVx5 → `https://cal.ironshark.org/` (user `xin`, sops
      `radicale-password`) for calendars; Vikunja app → `https://tasks.ironshark.org`.
- [ ] Phone: Paperless and Karakeep apps (`docs.` / `keep.ironshark.org`).
- [ ] LanguageTool in Obsidian and the Brave extension → `https://lt.ironshark.org`.
- [ ] Karakeep: make the first (admin) account, add the Brave extension.
- [ ] Immich: first login, then Administration → External Libraries.
- [ ] Google Drive: run `gdrive-login` once on Kvasir.
- [ ] Delete the old Web-type OAuth client in the Google console.

## Later

- [ ] Immich machine learning on the GPU (CUDA build, compiled on Akmon) if the
      library grows enough for it to matter.
- [ ] Karakeep: turn off sign-ups once the account exists (`DISABLE_SIGNUPS`).
- [ ] Hydrus, if exact tag-based image search turns out to be missing.
