{ inputs, ... }: {
  # One-way push of generated Radicale calendars into Google Calendar, every
  # 5 minutes (vdirsyncer, as xin). Radicale is only the staging area for
  # calendars Akmon writes (Super Productivity deadlines, task-deadlines.nix);
  # hand-made calendars live in Google itself. Anything changed on the Google
  # side of a pushed calendar is reverted on the next run.
  #
  # Adding a calendar: an empty one in Google, then one line:
  #   tn.calendarPush.calendars.<label> = { radicale = "<collection>"; google = "<calendar id>"; };
  # The Radicale collection is the path segment after /xin/ (the writer
  # creates it); `calendar-push-login` on Kvasir lists the
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
        # one calendar at a time with a second try: in one run over all of
        # them, Google drops connections ("Server disconnected") and the rest
        # of that calendar waits for the next run. Generated calendars may
        # empty out for real (every deadline done); vdirsyncer refuses that
        # without --force-delete, and Google is only a mirror.
        allow_empty=" ${lib.concatStringsSep " " (lib.attrNames (lib.filterAttrs (_: c: c.allowEmpty) cfg.calendars))} "
        sync() {
          case "$allow_empty" in
            *" $1 "*) ${vdir} -c ${conf} sync --force-delete "push/$1" ;;
            *)        ${vdir} -c ${conf} sync "push/$1" ;;
          esac
        }
        failed=()
        for c in ${lib.escapeShellArgs (lib.attrNames cfg.calendars)}; do
          sync "$c" || failed+=("$c")
        done
        rc=0
        for c in "''${failed[@]}"; do
          sleep 5
          sync "$c" || rc=1
        done
        exit $rc
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
          allowEmpty = lib.mkOption {
            type = lib.types.bool; default = false;
            description = "Mirror an emptied calendar (generated ones) instead of stopping as a safety check.";
          };
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
