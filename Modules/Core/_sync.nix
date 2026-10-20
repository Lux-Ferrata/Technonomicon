# The whole Syncthing topology, shared by Tn-dev-host (Akmon) and
# Tn-dev-client (Kvasir). Akmon is the always-on hub: every folder goes
# through it, so two devices never need to be online at the same time, and
# its copies on fast/srv/xin are snapshotted by sanoid. Folders and devices
# not listed here are removed from Syncthing (their files are left alone).
#
# Not here on purpose: Zotero (WebDAV, Tn-webdav); Technonomicon syncs
# through git + Forgejo; phone <-> laptop file drops are Taildrop.
{
  devices = {
    # Akmon's ID comes from its sops cert/key, so it survives reinstalls
    Akmon  = "ESFOH2J-SSO5QHZ-PPAZRYF-FKOMGQB-5HLWCBH-PCELXT5-FEGZQJ3-JMGH7Q5";
    Kvasir = "HCZVU5Z-ISVSPCK-4FP7HUF-K5AJSKO-H5VZFHL-WXHTZXJ-PFAMMDG-7TPOKAF";
    # shares Grimoire with Akmon (the hub); on the tailnet, dials tcp://akmon:22000
    Phone  = "PSINF7M-32THNKX-OK7AG7M-FZLYAJU-MKV4RID-FJSH5EQ-AC6JNQ2-76PGJAR";
  };

  # id -> label, path on Kvasir, directory under /srv/xin on Akmon, mode:
  #   twoway  edited on either side
  #   backup  Kvasir sends, Akmon only receives (and snapshots)
  # extraDevices: devices besides Kvasir that share it with Akmon (the hub)
  # The older folders keep the IDs they were created with.
  folders = {
    projects = {
      label  = "Projects";
      kvasir = "/home/xin/Projects";
      akmon  = "Projects";
      mode   = "twoway";
      # .git is synced on purpose (only one machine is active at a time).
      # Build outputs and per-machine envs are not: each host keeps its own
      # build cache. (?d): these may be deleted with their parent, or
      # removing a project leaves the other side stuck at <100%.
      ignorePatterns = [
        # git + Forgejo are its sync; syncing it scrambled Akmon once already
        "/Technonomicon"
        "(?d).direnv"
        "(?d)result"
        "(?d)result-*"
        "(?d)target"
        "(?d)node_modules"
        "(?d)dist-newstyle"
        "(?d).stack-work"
        "(?d)zig-out"
        "(?d).zig-cache"
        "(?d)__pycache__"
        "(?d).venv"
      ];
    };

    "tsjp9-6mmnk" = {
      label  = "Media";
      kvasir = "/home/xin/Media";
      akmon  = "Media";
      mode   = "backup";
    };

    # The Obsidian vault. Its git history is owned by Akmon alone
    # (Tn-grimoire snapshots it every 5 min), so .git never syncs: two
    # peers mutating one repo corrupts it.
    grimoire = {
      label  = "Grimoire";
      kvasir = "/home/xin/Grimoire";
      akmon  = "Grimoire";
      mode   = "twoway";
      extraDevices = [ "Phone" ];
      ignorePatterns = [
        "/.git"
        "*.sync-conflict-*"
        # per-machine Obsidian UI state
        ".obsidian/workspace.json"
        ".obsidian/workspaces.json"
        ".obsidian/workspace-mobile.json"
        ".obsidian/cache"
        ".claude/settings.local.json"
      ];
    };

    "fhd2w-omewe" = {
      label  = "Sioyek";
      kvasir = "/home/xin/.local/share/sioyek";
      akmon  = "Sioyek";
      mode   = "backup";
    };

    # Kvasir's local Vikunja: a consistent copy its backup timer writes
    # (Tn-vikunja); Akmon keeps the history in its snapshots
    vikunja = {
      label  = "Vikunja";
      kvasir = "/home/xin/.local/share/vikunja-backup";
      akmon  = "Vikunja";
      mode   = "backup";
    };

    # Drop images here from the laptop or the phone; Hydrus (Tn-hydrus)
    # imports them and deletes them, and the deletions sync back
    hydrus-inbox = {
      label  = "Hydrus Inbox";
      kvasir = "/home/xin/Hydrus Inbox";
      akmon  = "HydrusInbox";   # no spaces: srv-xin's install -d is unquoted
      mode   = "twoway";
      extraDevices = [ "Phone" ];
    };
  };
}
