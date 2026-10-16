# Akmon follows `working`, weekly: Wednesday's CI job (ci/nightly.sh) pushes
# the flake update to working around 03:00, and this picks it up. Not `main`:
# main is only a curated changelog, and following it rolled back anything
# deployed by hand since the last curation. Day to day, `deploy akmon` is how
# changes land. The flake comes from the local Forgejo over plain HTTP (repo
# is public on the tailnet), so root needs no git credentials. CI already
# built this exact system, so the "build" is just store lookups.
{ pkgs, ... }: {

  system.autoUpgrade = {
    enable  = true;
    flake   = "git+http://127.0.0.1:3000/xin/Technonomicon.git?ref=working#Akmon";
    upgrade = false;        # honour working's flake.lock, never update inputs here
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
    # The CI job holds its summary mail until 06:00. Switching restarts the
    # runner (its unit changes with the upgrade), which kills the job and
    # loses the mail (2026-10-14), so let it finish first; at most 2 h.
    path = [ pkgs.procps ];
    preStart = ''
      for i in $(seq 240); do
        pgrep -f 'ci/nightly.sh' >/dev/null || exit 0
        [ "$i" = 1 ] && echo "waiting for the CI job (ci/nightly.sh) to finish"
        sleep 30
      done
      echo "CI job still running after 2 h; upgrading anyway"
    '';
  };
}
