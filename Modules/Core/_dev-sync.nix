# Shared by Tn-dev-host and Tn-dev-client: the Syncthing "Projects" folder
# that keeps ~/Projects identical on Kvasir and Akmon.
{
  folderId = "projects";

  # Akmon's ID comes from its sops cert/key, so it survives reinstalls
  akmonId  = "ESFOH2J-SSO5QHZ-PPAZRYF-FKOMGQB-5HLWCBH-PCELXT5-FEGZQJ3-JMGH7Q5";
  kvasirId = "HCZVU5Z-ISVSPCK-4FP7HUF-K5AJSKO-H5VZFHL-WXHTZXJ-PFAMMDG-7TPOKAF";

  # .git is synced on purpose (only one machine is active at a time). Build
  # outputs and per-machine envs are not: each host keeps its own build cache.
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
    "(?d).DS_Store"
  ];
}
