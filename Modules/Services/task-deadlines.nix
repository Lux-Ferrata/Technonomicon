{ inputs, ... }: {
  # Super Productivity deadlines as read-only calendars: every 5 minutes the
  # app's WebDAV sync file (Tn-webdav, /srv/webdav/tasks) is turned into
  # Radicale calendars (_task-deadlines.py), which calendar-push mirrors to
  # Google. One way only; the sync file must stay unencrypted and single-file
  # (the default), or the unit fails and alerts.
  #
  # Every project lands in the default "🔒 Projects" calendar, titled
  # "[Project] task". Projects (or whole sidebar folders) that should stand
  # out get their own calendar:
  # make an empty Google calendar (Claude can, with the calendar-push token),
  # then
  #   tn.taskDeadlines.calendars.<label> = { name = "..."; projects = [ "<title>" ]; folders = [ "<folder>" ]; google = "<calendar id>"; };
  flake.nixosModules.Tn-task-deadlines = { config, lib, pkgs, ... }:
  let
    cfg  = config.tn.taskDeadlines;
    coll = label: "deadlines-${label}";

    convert = pkgs.writers.writePython3Bin "task-deadlines" {
      flakeIgnore = [ "E501" "W503" ];
    } (builtins.readFile ./_task-deadlines.py);

    settings = pkgs.writeText "task-deadlines.json" (builtins.toJSON {
      url     = "http://127.0.0.1:5232/xin/";
      user    = "xin";
      default = { collection = "task-deadlines"; name = "🔒 Projects"; };
      calendars = lib.mapAttrs' (label: c:
        lib.nameValuePair (coll label) { inherit (c) name projects folders; }) cfg.calendars;
    });
  in {
    options.tn.taskDeadlines.calendars = lib.mkOption {
      default = {};
      description = "Projects whose deadlines get their own calendar instead of the default one.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name     = lib.mkOption { type = lib.types.str; description = "Calendar name in Radicale."; };
          projects = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "Super Productivity project titles."; };
          folders  = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; description = "Sidebar folders whose projects (sub-folders too) go here."; };
          google   = lib.mkOption { type = lib.types.str; description = "Google calendar ID."; };
        };
      });
    };

    config = {
      systemd.services.task-deadlines = {
        description = "Write Super Productivity deadlines to Radicale calendars";
        after    = [ "radicale.service" "zfs-mount.service" ];
        requires = [ "zfs-mount.service" ];
        environment = {
          SP_DIR = "/srv/webdav/tasks";
          CONFIG = settings;
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

      # Google "Academic Deadlines (old)" is the hand-made one this replaced;
      # never point a calendar here at it (the push would wipe it)
      tn.taskDeadlines.calendars = {
        academic = {
          name = "🔒 Academics"; folders = [ "University" ];
          google = "c_07612d4356b2fe10dcf5330759186b2a6c8aba1d209dac0d1eb37590ddde2949@group.calendar.google.com";
        };
      };

      tn.calendarPush.calendars = {
        task-deadlines = {
          radicale = "task-deadlines";
          google   = "c_f200476eb0cdab5c8901fffc8b6b2359a3af29c94aab81b222e6703b66b180a5@group.calendar.google.com";
          allowEmpty = true;
        };
      } // lib.mapAttrs' (label: c:
        lib.nameValuePair (coll label) { radicale = coll label; inherit (c) google; allowEmpty = true; }) cfg.calendars;
    };
  };
}
