{ ... }: {
  flake.nixosModules.Tn-email = { config, lib, pkgs, ... }:
  let
    secrets = "${config.users.users.xin.home}/Projects/Technonomicon/_secrets.yaml";

    # One-time Google login for Akmon's calendar push (Tn-calendar-push):
    # the OAuth redirect lands on a random localhost port, so it runs here,
    # where the browser is. Lists the Google calendar IDs, then copies the
    # token to Akmon.
    calendarPushLogin = pkgs.writeShellApplication {
      name = "calendar-push-login";
      runtimeInputs = with pkgs; [ vdirsyncer sops openssh coreutils ];
      text = ''
        tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
        get() { sops -d --extract "[\"$1\"]" ${secrets}; }
        cat > "$tmp/config" <<EOF
        [general]
        status_path = "$tmp/status/"
        [pair list]
        a = "google"
        b = "local"
        collections = ["from a"]
        [storage google]
        type = "google_calendar"
        token_file = "$tmp/token"
        client_id = "$(get google-oauth-client-id)"
        client_secret = "$(get google-oauth-client-secret)"
        [storage local]
        type = "filesystem"
        path = "$tmp/cals/"
        fileext = ".ics"
        EOF
        vdirsyncer -c "$tmp/config" discover list < <(yes) >/dev/null
        echo "Google calendar IDs (for tn.calendarPush):"
        for d in "$tmp"/cals/*/; do d=''${d%/}; echo "  ''${d##*/}"; done
        scp -q "$tmp/token" akmon:/srv/xin/.calendar-push/google-token
        echo "token copied to Akmon"
      '';
    };
  in {
    environment.systemPackages = with pkgs; [
      # TUI email stack
      aerc
      notmuch
      isync
      msmtp
      # CalDAV calendar stack
      khal
      vdirsyncer
      calcurse
      calendarPushLogin
    ];

    # Radicale on Akmon (https://cal.ironshark.org) <-> ~/.local/share/calendars,
    # read and edited with khal. Two-way; offline edits go up next time.
    sops.secrets.radicale-password = { owner = "xin"; };

    home-manager.users.xin = {
      # ── Thunderbird: mail, calendar, RSS ───────────────────────────────
      # Gmail signs in with OAuth2 in Thunderbird's own window on first
      # start. "Archive" is Akmon's permanent copy (Tn-mail-archive), read-only
      # and full-text searchable; its password is sops mail-archive-password.
      # Calendars: the Google ones below (offline cache on; one Google login
      # in Thunderbird's window on first start). Feeds live in the "Feeds"
      # account.
      accounts.email.accounts = {
        ironshark = {
          primary     = true;
          address     = "xin@ironshark.org";
          userName    = "xin@ironshark.org";
          realName    = config.tn.full_name;
          flavor      = "gmail.com";
          thunderbird.enable = true;
        };
        archive = {
          address  = "archive@ironshark.org";   # never sends; just names the account
          userName = "xin";
          realName = "Archive (Akmon)";
          imap = { host = "mail.ironshark.org"; port = 993; tls.enable = true; };
          thunderbird = {
            enable   = true;
            settings = id: {
              # look only: no Trash/Sent/Drafts handling on a read-only store
              "mail.server.server_${id}.delete_model"   = 0;
              "mail.server.server_${id}.check_all_folders_for_new" = false;
            };
          };
        };
      };
      # Google Calendar is where calendars live; Thunderbird keeps an offline
      # copy. The 🔒 ones are generated on Akmon (task-deadlines.nix) and
      # read-only. Attribute names are the names shown in Thunderbird.
      accounts.calendar.basePath = ".local/share/hm-calendars";   # unused: remote only
      accounts.calendar.accounts = let
        google = id: { color, readOnly ? false, primary ? false }: {
          inherit primary;
          remote = {
            type     = "caldav";
            url      = "https://apidata.googleusercontent.com/caldav/v2/${
              lib.replaceStrings [ "@" "#" ] [ "%40" "%23" ] id}/events/";
            userName = "xin@ironshark.org";
          };
          thunderbird = { enable = true; inherit color readOnly; };
        };
      in {
        "Kevin Fanning" = google "xin@ironshark.org" { color = "#9fe1e7"; primary = true; };
        "Class Times"   = google "c_7882cd8419d72b633223f39c5eb2ae061710ba6c9eebb5a6d76a7ab0541641dd@group.calendar.google.com" { color = "#cca6ac"; };
        "Office Hours"  = google "c_bdaf0ac3c8f5e55db5da6d91ba1ad5ff8a1971189ebc857e9d10bcf8aeecde1e@group.calendar.google.com" { color = "#fa573c"; };
        "School"        = google "c_7faad55430eba0e6927d955fbd7fd36a45143b418a037ce674f02fee647eb2d7@group.calendar.google.com" { color = "#b99aff"; };
        "🔒 Projects"   = google "c_f200476eb0cdab5c8901fffc8b6b2359a3af29c94aab81b222e6703b66b180a5@group.calendar.google.com" { color = "#9fc6e7"; readOnly = true; };
        "🔒 Academics"  = google "c_07612d4356b2fe10dcf5330759186b2a6c8aba1d209dac0d1eb37590ddde2949@group.calendar.google.com" { color = "#d06b64"; readOnly = true; };
        "Holidays in United States" = google "en.usa#holiday@group.v.calendar.google.com" { color = "#16a765"; readOnly = true; };
        "Pima Honors Program" = google "c_3dvc4bkp9meoi57miql7demous@group.calendar.google.com" { color = "#b99aff"; readOnly = true; };
      };

      programs.thunderbird = {
        enable = true;
        profiles.default = {
          isDefault    = true;
          feedAccounts.Feeds = {};
          settings = {
            "mail.shell.checkDefaultClient"  = false;
            "datareporting.healthreport.uploadEnabled" = false;
            "toolkit.telemetry.enabled"      = false;
            "calendar.timezone.useSystemTimezone" = true;
          };
        };
      };

      xdg.configFile."vdirsyncer/config".text = ''
        [general]
        status_path = "~/.local/share/vdirsyncer/status/"

        [pair radicale]
        a = "radicale_remote"
        b = "radicale_local"
        collections = ["from a"]
        metadata = ["color", "displayname"]

        [storage radicale_remote]
        type = "caldav"
        url = "https://cal.ironshark.org/"
        username = "xin"
        password.fetch = ["command", "cat", "${config.sops.secrets.radicale-password.path}"]

        [storage radicale_local]
        type = "filesystem"
        path = "~/.local/share/calendars/"
        fileext = ".ics"
      '';
      xdg.configFile."khal/config".text = ''
        [calendars]
        [[radicale]]
        path = ~/.local/share/calendars/*
        type = discover
      '';

      systemd.user.services.vdirsyncer = {
        Unit.Description = "Sync calendars with Radicale";
        Service = {
          Type = "oneshot";
          # discover picks up calendars made elsewhere (InfCloud, phone)
          ExecStart = "${pkgs.writeShellScript "vdirsyncer-sync" ''
            yes | ${lib.getExe pkgs.vdirsyncer} discover >/dev/null
            ${lib.getExe pkgs.vdirsyncer} metasync
            ${lib.getExe pkgs.vdirsyncer} sync
          ''}";
        };
      };
      systemd.user.timers.vdirsyncer = {
        Unit.Description = "Sync calendars with Radicale every 15 minutes";
        Timer = { OnCalendar = "*:0/15"; OnStartupSec = "2min"; };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
