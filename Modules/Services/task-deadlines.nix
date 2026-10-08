{ inputs, ... }: {
  # Super Productivity deadlines as a read-only calendar: every 5 minutes the
  # app's WebDAV sync file (Tn-webdav, /srv/webdav/tasks) is turned into the
  # Radicale calendar "task-deadlines" (_task-deadlines.py), which
  # calendar-push mirrors to the Google calendar "Task Deadlines". One way
  # only; the sync file must stay unencrypted and single-file (the default),
  # or the unit fails and alerts.
  flake.nixosModules.Tn-task-deadlines = { config, lib, pkgs, ... }:
  let
    convert = pkgs.writers.writePython3Bin "task-deadlines" {
      flakeIgnore = [ "E501" ];
    } (builtins.readFile ./_task-deadlines.py);
  in {
    systemd.services.task-deadlines = {
      description = "Write Super Productivity deadlines to a Radicale calendar";
      after    = [ "radicale.service" "zfs-mount.service" ];
      requires = [ "zfs-mount.service" ];
      environment = {
        SP_DIR        = "/srv/webdav/tasks";
        RADICALE_URL  = "http://127.0.0.1:5232/xin/task-deadlines/";
        RADICALE_USER = "xin";
      };
      serviceConfig = {
        Type                = "oneshot";
        ExecStart           = lib.getExe convert;
        DynamicUser         = true;
        SupplementaryGroups = [ "webdav" ];   # reads the sync file
        StateDirectory      = "task-deadlines";
        LoadCredential      = "radicale:${config.sops.secrets.radicale-password.path}";
      };
    };
    systemd.timers.task-deadlines = {
      wantedBy  = [ "timers.target" ];
      timerConfig = { OnCalendar = "*:0/5"; Persistent = false; };
    };

    tn.calendarPush.calendars.task-deadlines = {
      radicale = "task-deadlines";
      google   = "c_f200476eb0cdab5c8901fffc8b6b2359a3af29c94aab81b222e6703b66b180a5@group.calendar.google.com";
    };
  };
}
