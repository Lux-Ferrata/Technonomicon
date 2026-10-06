# The whole Syncthing topology, shared by Tn-dev-host (Akmon) and
# Tn-dev-client (Kvasir). Akmon is the always-on hub: every folder goes
# through it, so two devices never need to be online at the same time, and
# its copies on fast/srv/xin are snapshotted by sanoid. Folders and devices
# not listed here are removed from Syncthing (their files are left alone).
#
# Not here on purpose: Grimoire and Zotero get dedicated sync services;
# Technonomicon syncs through git + Forgejo.
{
  devices = {
    # Akmon's ID comes from its sops cert/key, so it survives reinstalls
    Akmon  = "ESFOH2J-SSO5QHZ-PPAZRYF-FKOMGQB-5HLWCBH-PCELXT5-FEGZQJ3-JMGH7Q5";
    Kvasir = "HCZVU5Z-ISVSPCK-4FP7HUF-K5AJSKO-H5VZFHL-WXHTZXJ-PFAMMDG-7TPOKAF";
    # on the tailnet; reaches Akmon at tcp://akmon:22000
    Phone  = "PSINF7M-32THNKX-OK7AG7M-FZLYAJU-MKV4RID-FJSH5EQ-AC6JNQ2-76PGJAR";
  };

  # id -> label, path on Kvasir, directory under /srv/xin on Akmon, which
  # devices besides Kvasir/Akmon get it, and the mode:
  #   twoway  edited on either side
  #   backup  Kvasir sends, Akmon only receives (and snapshots)
  # The older folders keep the IDs they were created with.
  folders = {
    projects = {
      label  = "Projects";
      kvasir = "/home/xin/Projects";
      akmon  = "Projects";
      mode   = "twoway";
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

    # drop a file in on the phone or the laptop, it shows up on the other
    transfer = {
      label  = "Transfer";
      kvasir = "/home/xin/Transfer";
      akmon  = "Transfer";
      mode   = "twoway";
      extraDevices = [ "Phone" ];
    };

    "tsjp9-6mmnk" = {
      label  = "Media";
      kvasir = "/home/xin/Media";
      akmon  = "Media";
      mode   = "backup";
    };

    "fhd2w-omewe" = {
      label  = "Sioyek";
      kvasir = "/home/xin/.local/share/sioyek";
      akmon  = "Sioyek";
      mode   = "backup";
    };
  };
}
