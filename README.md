# Technonomicon

Personal NixOS system configuration for Akmon (desktop) and Kvasir (ThinkPad T480s).

## Post-install steps

### Zotero — move data out of home root

Zotero defaults to `~/Zotero`. To move it to a hidden directory:

1. Open Zotero → **Edit → Preferences → Advanced → Files and Folders**
2. Under **Data Directory Location**, select **Custom** and set it to `~/.zotero`
3. Zotero will offer to move existing data — accept
4. Delete the old directory: `rm -rf ~/Zotero`


## Major Changes
- [ ] switch to BTRFS
- [ ] Enable Impermance and TmpFS
- [ ] Full Disk Encryption
- [ ] Create Refrence Boot Image
- [ ] Hyprland stacking Layout. (custom doom-emacs style buffer management)

### Not sure if it is worth actually making these changes
- [ ] Switch Phone and Tablet to Graphene and Lineage OS ?
- [ ] Move website and personal code to codeberg, with github mirror ?
- [ ] nix droid ?
- [ ] Aurora android app store
- [ ] switch to proton suite instead of gsuite ?

