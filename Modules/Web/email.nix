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
