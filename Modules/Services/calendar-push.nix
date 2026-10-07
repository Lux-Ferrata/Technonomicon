{ inputs, ... }: {
  # One-way push of chosen Radicale calendars into Google Calendar, every
  # 5 minutes (vdirsyncer, as xin). Radicale is read-only to it; anything
  # changed on the Google side is reverted on the next run. Nothing is
  # published; Google is just another (write-only) client.
  #
  # Adding a calendar: make it in Radicale (InfCloud / DAVx5) and an empty
  # one in Google, then one line here:
  #   tn.calendarPush.calendars.<label> = { radicale = "<collection>"; google = "<calendar id>"; };
  # The Radicale collection is the path segment after /xin/ (InfCloud's
  # calendar properties show it); `calendar-push-login` on Kvasir lists the
  # Google calendar IDs.
  #
  # One-time setup: the Google OAuth client ID/secret in sops
  # (google-oauth-client-id / -secret), then `calendar-push-login` on Kvasir,
  # which logs in through the browser and copies the token here.
  flake.nixosModules.Tn-calendar-push = { config, lib, pkgs, ... }:
  let
    cfg   = config.tn.calendarPush;
    state = "/srv/xin/.calendar-push";
    sec   = config.sops.secrets;
    vdir  = lib.getExe pkgs.vdirsyncer;

    cmd = path: ''{ fetch = ["command", "cat", "${path}"] }'';   # unused when inline
    conf = pkgs.writeText "calendar-push.conf" ''
      [general]
      status_path = "${state}/status/"

      [pair push]
      a = "radicale"
      b = "google"
      collections = ${builtins.toJSON (lib.mapAttrsToList (n: c: [ n c.radicale c.google ]) cfg.calendars)}
      conflict_resolution = "a wins"
      partial_sync = "revert"

      [storage radicale]
      type = "caldav"
      url = "http://127.0.0.1:5232/"
      username = "xin"
      password.fetch = ["command", "cat", "${sec.radicale-password.path}"]
      read_only = true

      [storage google]
      type = "google_calendar"
      token_file = "${state}/google-token"
      client_id.fetch = ["command", "cat", "${sec.google-oauth-client-id.path}"]
      client_secret.fetch = ["command", "cat", "${sec.google-oauth-client-secret.path}"]
    '';

    push = pkgs.writeShellApplication {
      name = "calendar-push";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        [ -s ${state}/google-token ] || { echo "no Google token yet: run calendar-push-login on Kvasir" >&2; exit 0; }
        # (re)discover only when the calendar list changed
        if [ "$(cat ${state}/discovered 2>/dev/null)" != ${conf} ]; then
          ${vdir} -c ${conf} discover push
          echo ${conf} > ${state}/discovered
        fi
        ${vdir} -c ${conf} sync
      '';
    };
  in {
    options.tn.calendarPush.calendars = lib.mkOption {
      default = {};
      description = "Radicale calendars pushed one-way to Google Calendar.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          radicale = lib.mkOption { type = lib.types.str; description = "Radicale collection under /xin/."; };
          google   = lib.mkOption { type = lib.types.str; description = "Google calendar ID."; };
        };
      });
    };

    config = lib.mkMerge [
      {
        sops.secrets.radicale-password = { owner = "xin"; };
        systemd.tmpfiles.rules = [ "d ${state} 0700 xin users -" ];
      }
      # the OAuth secrets only exist once the client is made, so nothing that
      # needs them is declared before the first calendar
      (lib.mkIf (cfg.calendars != {}) {
        sops.secrets.google-oauth-client-id     = { owner = "xin"; };
        sops.secrets.google-oauth-client-secret = { owner = "xin"; };

        home-manager.users.xin.systemd.user = {
          services.calendar-push = {
            Unit.Description = "Push Radicale calendars to Google Calendar";
            Service = {
              Type      = "oneshot";
              ExecStart = lib.getExe push;
              Nice      = 10;
            };
          };
          timers.calendar-push = {
            Unit.Description = "Push calendars to Google every 5 minutes";
            Timer = { OnCalendar = "*:0/5"; Persistent = false; };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      })
    ];
  };
}
