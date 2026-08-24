# Technonomicon

Personal NixOS system configuration for Akmon (desktop) and Kvasir (ThinkPad T480s).

## Post-install steps

### Zotero — move data out of home root

Zotero defaults to `~/Zotero`. To move it to a hidden directory:

1. Open Zotero → **Edit → Preferences → Advanced → Files and Folders**
2. Under **Data Directory Location**, select **Custom** and set it to `~/.zotero`
3. Zotero will offer to move existing data — accept
4. Delete the old directory: `rm -rf ~/Zotero`

### Zotero — Better BibTeX + Grimoire library export

The Grimoire vault's literature layer (Citation plugin + blog citations) feeds off a single
auto-updating BibLaTeX file. Zotero 8+ has native citation keys; Better BibTeX (BBT) is here for
the *keep-updated `.bib` export*.

1. Install **Better BibTeX v9.x** (supports Zotero 8/9): download the `.xpi` from
   <https://github.com/retorquere/zotero-better-bibtex/releases>, then Zotero → **Tools → Plugins →
   gear → Install Plugin From File** → pick the `.xpi`. Restart Zotero.
2. Ensure the target dir exists: `mkdir -p ~/.local/share/zotero`
3. In Zotero, right-click **My Library** → **Export Library…**
   - Format: **Better BibLaTeX**
   - Check **Keep updated**
   - Save as `~/.local/share/zotero/grimoire-library.bib`
4. Confirm **Settings → Better BibTeX → Automatic export = On change** so the file self-updates.
   The Obsidian Citation plugin and the blog's `import-from-grimoire.py` both point at this exact path.

## Phone Updates
  - Tailscale + Mulvad always on
  - syncthing syncthing
  - Obsidian and Superproductivity


## Major Changes
- [ ] switch to BTRFS
- [ ] Enable Impermance and TmpFS
- [ ] Full Disk Encryption
- [ ] Create Refrence Boot Image
- [ ] Install and Configure Wl-Kbptr. The derivation already exists — `wlKbptr` in `Modules/Core/hyprland.nix` overrides `pkgs.wl-kbptr` with `-Dopencv=enabled` — but it is never added to `environment.systemPackages` and has no keybinding, so nothing is installed. It did not work correctly the last time it was attempted, so the config needs a fresh look, not just wiring up.
- [ ] Configure [khal](https://github.com/pimutils/khal) CalDAV calendar. The package is already in `Tn-email` (with `vdirsyncer` and `calcurse`), but that module is not imported by Kvasir and there is no `~/.config/khal` or `~/.config/vdirsyncer` yet, so nothing is running. Needed for the Grimoire wish of getting todos with deadlines onto the calendar automatically.

### Not sure if it is worth actually making these changes
- [ ] Switch Phone and Tablet to Graphene and Lineage OS ?
- [ ] Move website and personal code to codeberg, with github mirror ?
- [ ] nix droid ?
- [ ] Aurora android app store
- [ ] switch to proton suite instead of gsuite ?

## Homelab
- [ ] Hydrus picture and gif serever. (Find out about ml image recognition, seach, and tagging)
- [ ] Language tool server for obsidian grammar and spell checking
- [ ] Superproductivity Time Tracking

