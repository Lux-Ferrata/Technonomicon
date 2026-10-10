{ inputs, ... }: {
  # Vikunja (tasks), local-first on Kvasir: works offline at
  # http://localhost:3456 (the "Tasks (Vikunja)" launcher), and over the
  # tailnet at https://kvasir.tail607809.ts.net while the laptop is up
  # (phone: the Vikunja app, or CalDAV at /dav/ with a CalDAV token).
  # SQLite + attachments live in /var/lib/private/vikunja (DynamicUser).
  #
  # The server writes its public URL into the page as the API address, and
  # logins renew through a cookie that browsers only send to the same site.
  # So the public URL is localhost (the laptop page never leaves the
  # machine, and works offline), and the tailnet goes through a local nginx
  # that swaps in the tailnet name. Pointing the page at the tailnet name
  # instead logged the localhost page out every 10 minutes.
  #
  # Backup: every 15 min, if anything changed, a consistent copy goes to
  # ~/.local/share/vikunja-backup, a Syncthing backup folder (_sync.nix)
  # that lands in Akmon's /srv/xin/Vikunja (snapshotted by sanoid).
  # Restore: systemctl stop vikunja; copy vikunja.db and files/ from the
  # backup into /var/lib/private/vikunja (owned by the vikunja DynamicUser:
  # chown to the uid of the existing dir); systemctl start vikunja.
  flake.nixosModules.Tn-vikunja = { config, lib, pkgs, ... }:
  let
    cfg    = config.services.vikunja;
    user   = "xin";
    tsName = "kvasir.tail607809.ts.net";
    local  = "http://localhost:${toString cfg.port}";
    proxy  = 3457;   # tailnet side: nginx, rewriting the API address
    state  = "/var/lib/private/vikunja";
    dest   = "/home/xin/.local/share/vikunja-backup";
  in {
    sops.secrets.vikunja-password = {};
    sops.secrets.vikunja-secret   = {};
    # read by systemd (root) for EnvironmentFile, so the DynamicUser needn't;
    # a fixed secret keeps logins valid across restarts
    sops.templates."vikunja.env".content = ''
      VIKUNJA_SERVICE_SECRET=${config.sops.placeholder.vikunja-secret}
    '';

    services.vikunja = {
      enable           = true;
      address          = "127.0.0.1";
      port             = 3456;
      frontendScheme   = "http";
      frontendHostname = "localhost:${toString cfg.port}";
      environmentFiles = [ config.sops.templates."vikunja.env".path ];
      settings.service = {
        enableregistration = false;
        timezone           = config.time.timeZone;
      };
    };

    systemd.services.vikunja = {
      serviceConfig.LoadCredential = "password:${config.sops.secrets.vikunja-password.path}";
      # idempotent: create the account once the server (and its migrations) is up
      postStart = ''
        for _ in $(seq 60); do vikunja healthcheck >/dev/null 2>&1 && break; sleep 1; done
        users=$(vikunja user list 2>/dev/null || true)
        # the username column, exactly (tablewriter draws │ or | borders)
        row() { vikunja user list 2>/dev/null | grep -E '(│|\|) *${user} *(│|\|)' || true; }
        # only on an empty instance: a restored backup brings its own accounts
        if ! grep -qE '^(│|\|) *[0-9]+ ' <<<"$users"; then
          vikunja user create -u ${user} -e xin@ironshark.org \
            -p "$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/password")" \
            || echo "vikunja: could not create ${user} (already there?)" >&2
        fi
        if [ -n "$(row)" ] && ! row | grep -q Active; then
          vikunja user change-status --enable ${user}
        fi
      '';
    };

    services.nginx = {
      enable = true;
      virtualHosts."vikunja-tailnet" = {
        listen = [ { addr = "127.0.0.1"; port = proxy; } ];
        locations."/" = {
          proxyPass       = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Accept-Encoding "";   # sub_filter needs it plain
            sub_filter '${local}' 'https://${tsName}';
            sub_filter_once on;
            client_max_body_size 50m;              # attachments
          '';
        };
      };
    };

    # https://kvasir.<tailnet>.ts.net -> the proxy above; tailscaled
    # terminates TLS with a tailnet cert, so no firewall port opens
    systemd.services.vikunja-tailnet = {
      description = "Serve Vikunja on the tailnet";
      after    = [ "tailscaled.service" "network-online.target" ];
      wants    = [ "tailscaled.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        Restart         = "on-failure";
        RestartSec      = 30;
      };
      script = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:${toString proxy}";
    };

    # exists before Syncthing looks for it
    systemd.tmpfiles.rules = [ "d ${dest} 0755 xin users -" ];

    systemd.services.vikunja-backup = {
      description = "Copy Vikunja's data for Akmon";
      path = [ pkgs.sqlite pkgs.rsync pkgs.findutils pkgs.coreutils ];
      serviceConfig = {
        Type              = "oneshot";
        Nice              = 19;
        IOSchedulingClass = "idle";
      };
      script = ''
        [ -f ${state}/vikunja.db ] || { echo "no database yet"; exit 0; }
        mkdir -p ${dest}/files
        # only when something changed since the last copy
        if [ -f ${dest}/vikunja.db ] &&
           [ -z "$(find ${state}/vikunja.db* ${state}/files -newer ${dest}/vikunja.db 2>/dev/null | head -1)" ]; then
          echo "unchanged"; exit 0
        fi
        rm -f ${dest}/vikunja.db.tmp
        # hot, consistent copy; mv so Syncthing never sees half a file
        sqlite3 ${state}/vikunja.db ".backup '${dest}/vikunja.db.tmp'"
        if [ -d ${state}/files ]; then rsync -a --delete ${state}/files/ ${dest}/files/; fi
        mv ${dest}/vikunja.db.tmp ${dest}/vikunja.db
        chown -R xin:users ${dest}
        echo "copied"
      '';
    };
    systemd.timers.vikunja-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnBootSec = "5min"; OnUnitActiveSec = "15min"; };
    };
  };
}
