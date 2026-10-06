# The whole Syncthing topology, shared by Tn-dev-host (Akmon) and
# Tn-dev-client (Kvasir). Akmon is the always-on hub: every folder goes
# through it, and its copies on fast/srv/xin are snapshotted by sanoid, which
# makes it the backup too. Folders not listed here are removed from Syncthing
# (their files are left alone).
{
  devices = {
    # Akmon's ID comes from its sops cert/key, so it survives reinstalls
    Akmon  = "ESFOH2J-SSO5QHZ-PPAZRYF-FKOMGQB-5HLWCBH-PCELXT5-FEGZQJ3-JMGH7Q5";
    Kvasir = "HCZVU5Z-ISVSPCK-4FP7HUF-K5AJSKO-H5VZFHL-WXHTZXJ-PFAMMDG-7TPOKAF";
  };

  # id -> label, path on Kvasir, directory under /srv/xin on Akmon, ignores.
  # The older folders keep the IDs they were created with.
  folders = {
    projects = {
      label  = "Projects";
      kvasir = "/home/xin/Projects";
      akmon  = "Projects";
      # .git is synced on purpose (only one machine is active at a time).
      # Build outputs and per-machine envs are not: each host keeps its own
      # build cache.
      ignorePatterns = [
        # git + Forgejo are its sync; syncing it scrambled Akmon once already
        "/Technonomicon"
        ".direnv"
        "result"
        "result-*"
        "target"
        "node_modules"
        "dist-newstyle"
        ".stack-work"
        "zig-out"
        ".zig-cache"
        "__pycache__"
        ".venv"
      ];
    };

    "mzj3a-ivrmw" = {
      label  = "Grimoire";
      kvasir = "/home/xin/Grimoire";
      akmon  = "Grimoire";
      ignorePatterns = [
        # git is owned by one machine; two peers mutating .git corrupts it
        "/.git"
        "*.sync-conflict-*"
        # per-machine Obsidian UI state
        ".obsidian/workspace.json"
        ".obsidian/workspaces.json"
        ".obsidian/workspace-mobile.json"
      ];
    };

    "r7inw-xwy5h" = {
      label  = "Zotero Media";
      kvasir = "/home/xin/.zotero/zotero/storage";
      akmon  = "Zotero";
    };

    "tsjp9-6mmnk" = {
      label  = "Media";
      kvasir = "/home/xin/Media";
      akmon  = "Media";
    };

    "fhd2w-omewe" = {
      label  = "Sioyek";
      kvasir = "/home/xin/.local/share/sioyek";
      akmon  = "Sioyek";
    };
  };
}
