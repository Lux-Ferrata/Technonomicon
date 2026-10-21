{ ... }: {
  flake.nixosModules.Tn-email = { config, lib, pkgs, pkgs-stable, ... }:
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

    # The Google calendars, for Thunderbird and khal. The 🔒 ones are generated
    # on Akmon (task-deadlines.nix) and read-only.
    calendars = {
      "Kevin Fanning" = { id = "xin@ironshark.org"; color = "#9fe1e7"; primary = true; };
      "Class Times"   = { id = "c_7882cd8419d72b633223f39c5eb2ae061710ba6c9eebb5a6d76a7ab0541641dd@group.calendar.google.com"; color = "#cca6ac"; };
      "Office Hours"  = { id = "c_bdaf0ac3c8f5e55db5da6d91ba1ad5ff8a1971189ebc857e9d10bcf8aeecde1e@group.calendar.google.com"; color = "#fa573c"; };
      "School"        = { id = "c_7faad55430eba0e6927d955fbd7fd36a45143b418a037ce674f02fee647eb2d7@group.calendar.google.com"; color = "#b99aff"; };
      "🔒 Projects"   = { id = "c_f200476eb0cdab5c8901fffc8b6b2359a3af29c94aab81b222e6703b66b180a5@group.calendar.google.com"; color = "#9fc6e7"; readOnly = true; };
      "🔒 Academics"  = { id = "c_07612d4356b2fe10dcf5330759186b2a6c8aba1d209dac0d1eb37590ddde2949@group.calendar.google.com"; color = "#d06b64"; readOnly = true; };
      "Holidays in United States" = { id = "en.usa#holiday@group.v.calendar.google.com"; vdirId = "cln2stbjc4hmgrrcd5i62ua0ctp6utbg5pr2sor1dhimsp31e8n6errfctm6abj3dtmg@virtual"; color = "#16a765"; readOnly = true; };
      "Pima Honors Program" = { id = "c_3dvc4bkp9meoi57miql7demous@group.calendar.google.com"; color = "#b99aff"; readOnly = true;
                                # not in the account's CalDAV calendar list, so vdirsyncer can't reach it
                                khal = false; };
    };
    # vdirsyncer's Google API lists some calendars under another ID
    vdirId   = c: c.vdirId or c.id;
    khalCals = lib.filterAttrs (_: c: c.khal or true) calendars;
    calData  = "${config.users.users.xin.home}/.local/share/google-calendars";
    calState = "${config.users.users.xin.home}/.local/state/vdirsyncer";

    # ikhal between two syncs; the first run signs in to Google (browser)
    tnCal = pkgs.writeShellApplication {
      name = "tn-cal";
      runtimeInputs = [ pkgs-stable.khal ] ++ (with pkgs; [ vdirsyncer coreutils ]);
      text = ''
        if [ ! -f "${calState}/google-token" ]; then
          echo "First run: sign in to Google as xin@ironshark.org in the browser."
          yes | vdirsyncer discover >/dev/null
          systemctl --user start vdirsyncer.timer || true
        fi
        vdirsyncer sync >/dev/null 2>&1 || echo "offline: showing the local copy" >&2
        ikhal
        vdirsyncer sync >/dev/null 2>&1 || true
      '';
    };

    # aerc's Google OAuth2 logins (Pima): `mail-oauth login <address>` once,
    # then aerc runs `mail-oauth token <address>` for each connection
    mailOauth = pkgs.writers.writePython3Bin "mail-oauth" {
      flakeIgnore = [ "E501" ];
    } (builtins.readFile ./_mail-oauth.py);

    # aerc on the same Gmail mailboxes as Thunderbird (labels are folders,
    # so either client sees what the other did). Gmail files sent mail
    # itself, so no copy-to.
    aercGmail = address: auth: {
      enable = true;
      extraAccounts = {
        from     = address;   # no display name, as in Thunderbird
        copy-to  = "";
        default  = "INBOX";
        postpone = "[Gmail]/Drafts";
        archive  = "[Gmail]/All Mail";
      };
    } // auth;
  in {
    # aerc and vdirsyncer read these as xin: the ironshark app password and
    # the OAuth client
    sops.secrets.smtp-password              = { owner = "xin"; };
    sops.secrets.google-oauth-client-id     = { owner = "xin"; };
    sops.secrets.google-oauth-client-secret = { owner = "xin"; };

    environment.systemPackages = with pkgs; [
      # TUI email stack
      aerc
      notmuch
      isync
      msmtp
      # Calendars live in Google; Thunderbird and khal (below) keep offline copies
      pkgs-stable.khal   # 2026-10-21: unstable's khal build fails (empty man output); use stable's
      vdirsyncer
      tnCal
      calendarPushLogin
      mailOauth
      w3m   # aerc's text/html filter
    ];

    home-manager.users.xin = {
      # ── Thunderbird: mail, calendar ────────────────────────────────────
      # Gmail and Pima sign in with OAuth2 in Thunderbird's own window on first
      # start. "Archive" is Akmon's permanent copy (Tn-mail-archive), read-only
      # and full-text searchable; its password is sops mail-archive-password.
      # Calendars: the Google ones below (offline cache on; one Google login
      # in Thunderbird's window on first start). RSS lives in Miniflux
      # (Tn-miniflux), not here.
      accounts.email.accounts = {
        ironshark = {
          primary     = true;
          address     = "xin@ironshark.org";
          userName    = "xin@ironshark.org";
          realName    = "";   # bare address in From, no display name
          flavor      = "gmail.com";
          thunderbird.enable = true;
          # aerc: the Workspace app password (also Akmon's mail relay/archive)
          passwordCommand = "cat ${config.sops.secrets.smtp-password.path}";
          aerc = aercGmail "xin@ironshark.org" {};
        };
        # Pima Community College (Google Workspace): OAuth2 like the above
        pima = {
          address     = "kfanning2@mail.pima.edu";
          userName    = "kfanning2@mail.pima.edu";
          realName    = "";   # bare address in From, no display name
          flavor      = "gmail.com";
          thunderbird.enable = true;
          # aerc: OAuth2 (`mail-oauth login kfanning2@mail.pima.edu` once)
          passwordCommand = "${lib.getExe mailOauth} token kfanning2@mail.pima.edu";
          aerc = aercGmail "kfanning2@mail.pima.edu" { imapAuth = "oauthbearer"; smtpAuth = "oauthbearer"; };
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
      # copy. Attribute names are the names shown in Thunderbird.
      accounts.calendar.basePath = ".local/share/hm-calendars";   # unused: remote only
      accounts.calendar.accounts = lib.mapAttrs (_: c: {
        primary = c.primary or false;
        remote = {
          type     = "caldav";
          url      = "https://apidata.googleusercontent.com/caldav/v2/${
            lib.replaceStrings [ "@" "#" ] [ "%40" "%23" ] c.id}/events/";
          userName = "xin@ironshark.org";
        };
        thunderbird = { enable = true; inherit (c) color; readOnly = c.readOnly or false; };
      }) calendars;

      # khal: the same calendars in the terminal (ikhal, or "Calendar" in the
      # launcher). vdirsyncer keeps a local copy in sync with Google every
      # 15 minutes and around each `tn-cal`; the first `tn-cal` signs in.
      xdg.configFile."vdirsyncer/config".text = ''
        [general]
        status_path = "${calState}/status/"

        [pair google]
        a = "google_local"
        b = "google_remote"
        collections = [${lib.concatMapStringsSep ", " (c: ''"${vdirId c}"'') (lib.attrValues khalCals)}]
        conflict_resolution = "b wins"

        [storage google_local]
        type = "filesystem"
        path = "${calData}/"
        fileext = ".ics"

        [storage google_remote]
        type = "google_calendar"
        token_file = "${calState}/google-token"
        client_id.fetch = ["command", "cat", "${config.sops.secrets.google-oauth-client-id.path}"]
        client_secret.fetch = ["command", "cat", "${config.sops.secrets.google-oauth-client-secret.path}"]
      '';
      xdg.configFile."khal/config".text = ''
        [calendars]
        ${lib.concatStrings (lib.mapAttrsToList (name: c: ''
          [[${name}]]
          path = '${calData}/${vdirId c}'   # quoted: '#' starts a comment
          color = '${c.color}'
          readonly = ${if c.readOnly or false then "True" else "False"}
        '') khalCals)}
        [default]
        default_calendar = Kevin Fanning
        highlight_event_days = True

        [locale]
        timeformat = %H:%M
        dateformat = %Y-%m-%d
        longdateformat = %Y-%m-%d
        datetimeformat = %Y-%m-%d %H:%M
        longdatetimeformat = %Y-%m-%d %H:%M
        firstweekday = 0
      '';
      systemd.user.services.vdirsyncer = {
        Unit = {
          Description = "Sync khal's calendars with Google";
          ConditionPathExists = "${calState}/google-token";   # after the first tn-cal
        };
        Service = { Type = "oneshot"; ExecStart = "${lib.getExe pkgs.vdirsyncer} sync"; };
      };
      systemd.user.timers.vdirsyncer = {
        Unit.Description = "Sync khal's calendars with Google";
        Timer = { OnCalendar = "*:0/15"; Persistent = true; };
        Install.WantedBy = [ "timers.target" ];
      };

      # Super+Space: "Mail" and "Calendar", in a terminal
      xdg.desktopEntries = {
        aerc = {
          name = "Mail"; genericName = "aerc"; icon = "${./icons/mail.svg}";
          exec = "aerc"; terminal = true; categories = [ "Network" "Email" ];
        };
        tn-cal = {
          name = "Calendar"; genericName = "khal"; icon = "${./icons/calendar.svg}";
          exec = "tn-cal"; terminal = true; categories = [ "Office" "Calendar" ];
        };
      };

      programs.aerc = {
        enable = true;
        extraConfig = {
          # accounts.conf is generated into the store; it holds commands, not
          # passwords
          general.unsafe-accounts-conf = true;
          filters = {
            "text/plain"  = "colorize";
            "text/html"   = "! html";
            "text/calendar" = "calendar";
            "message/delivery-status" = "colorize";
            "message/rfc822" = "colorize";
          };
        };
      };

      programs.thunderbird = {
        enable = true;
        profiles.default = {
          isDefault    = true;
          settings = {
            "mail.shell.checkDefaultClient"  = false;
            "datareporting.healthreport.uploadEnabled" = false;
            "toolkit.telemetry.enabled"      = false;
            "calendar.timezone.useSystemTimezone" = true;
          };
        };
      };
    };
  };
}
