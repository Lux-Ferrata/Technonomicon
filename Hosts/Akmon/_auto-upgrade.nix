# Akmon follows `working`, weekly: Wednesday's CI job (ci/nightly.sh) pushes
# the flake update to working around 03:00, and this picks it up. Not `main`:
# main is only a curated changelog, and following it rolled back anything
# deployed by hand since the last curation. Day to day, `deploy akmon` is how
# changes land. The flake comes from the local Forgejo over plain HTTP (repo
# is public on the tailnet), so root needs no git credentials. CI already
# built this exact system, so the "build" is just store lookups.
{ ... }: {

  system.autoUpgrade = {
    enable  = true;
    flake   = "git+http://127.0.0.1:3000/xin/Technonomicon.git?ref=working#Akmon";
    upgrade = false;        # honour main's flake.lock, never update inputs here
    dates   = "Wed 05:30";  # the job starts 03:00; usually done long before.
                            # Before the 06:00 alert digest, which reports on it
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
