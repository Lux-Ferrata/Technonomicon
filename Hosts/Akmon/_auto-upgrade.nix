# Akmon follows `main` (written only by the weekly CI job, see ci/weekly.sh).
# Daily so a manual re-run of the job also lands; when main hasn't moved this
# is a no-op. The flake comes from the local Forgejo over plain HTTP (repo is
# public on the tailnet), so root needs no git credentials. CI already built
# this exact system, so the "build" is just store lookups.
{ ... }: {

  system.autoUpgrade = {
    enable  = true;
    flake   = "git+http://127.0.0.1:3000/xin/Technonomicon.git?ref=main#Akmon";
    upgrade = false;        # honour main's flake.lock, never update inputs here
    dates   = "06:00";      # Wed's job starts 03:00; usually done long before
    # reboot only when kernel/initrd/modules changed, and only at night
    allowReboot  = true;
    rebootWindow = { lower = "05:00"; upper = "07:00"; };
  };

  # failures mail via the global notify-failure drop-in (Tn-server-alerts)
  systemd.services.nixos-upgrade = {
    after = [ "forgejo.service" ];
    wants = [ "forgejo.service" ];
  };
}
