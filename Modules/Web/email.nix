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
      # Calendars: File > New > Calendar > On the Network, URL
      # https://cal.ironshark.org/ (Radicale, finds them all); Google Calendar
      # the same way with a Google login. Feeds live in the "Feeds" account.
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
      # ── Tasks offline: Vikunja's projects as cached CalDAV calendars ─────
      # Thunderbird keeps a local copy (cache.enabled), so tasks stay readable
      # and editable without Akmon; edits go up when it's reachable again.
      # Vikunja (Tn-vikunja) stays the source of truth; the desktop app is the
      # online view with kanban. Thunderbird asks for the Vikunja password
      # (sops vikunja-password) once. The project list is shared with Akmon
      # (Modules/Services/_vikunja-projects.nix), which notices new projects.
      accounts.calendar.basePath = ".local/share/hm-calendars";   # unused: Thunderbird stores its own cache
      accounts.calendar.accounts = lib.mapAttrs' (title: id: lib.nameValuePair "Tasks: ${title}" {
        remote = {
          type     = "caldav";
          url      = "https://tasks.ironshark.org/dav/projects/${toString id}/";
          userName = "xin";
        };
        thunderbird.enable = true;
      }) (import ../Services/_vikunja-projects.nix);

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
