{ inputs, ... }: {
  # Vikunja (tasks) at https://tasks.ironshark.org, on the shared Postgres.
  # Registration is off; the one account (xin) is created from sops on
  # first start. Phone: the Vikunja app, or CalDAV at
  # https://tasks.ironshark.org/dav/ (DAVx5 + Tasks.org, with a CalDAV token
  # made in Settings).
  flake.nixosModules.Tn-vikunja = { config, lib, pkgs, ... }:
  let
    cfg  = config.services.vikunja;
    user = "xin";
  in {
    sops.secrets.vikunja-password = {};
    sops.secrets.vikunja-secret   = {};
    # read by systemd (root) for EnvironmentFile, so the DynamicUser needn't
    sops.templates."vikunja.env".content = ''
      VIKUNJA_SERVICE_SECRET=${config.sops.placeholder.vikunja-secret}
      VIKUNJA_MAILER_PASSWORD=${config.sops.placeholder.smtp-password}
    '';

    services.vikunja = {
      enable           = true;
      address          = "127.0.0.1";
      port             = 3456;
      frontendScheme   = "https";
      frontendHostname = "tasks.ironshark.org";
      environmentFiles = [ config.sops.templates."vikunja.env".path ];
      # DynamicUser "vikunja" -> Postgres peer auth as the same name
      database = { type = "postgres"; host = "/run/postgresql"; };
      settings = {
        service = {
          enableregistration = false;
          timezone           = config.time.timeZone;
        };
        mailer = {
          enabled   = true;
          host      = "smtp.gmail.com";
          port      = 587;
          username  = "xin@ironshark.org";
          fromemail = "homelab@ironshark.org";
        };
      };
    };

    services.postgresql = {
      ensureDatabases = [ "vikunja" ];
      ensureUsers = [ { name = "vikunja"; ensureDBOwnership = true; } ];
    };

    systemd.services.vikunja = {
      requires = [ "postgresql.target" ];
      serviceConfig.LoadCredential = "password:${config.sops.secrets.vikunja-password.path}";
      # idempotent: create the account once the server (and its migrations) is up
      postStart = ''
        for _ in $(seq 60); do vikunja healthcheck >/dev/null 2>&1 && break; sleep 1; done
        users=$(vikunja user list 2>/dev/null || true)
        # the username column, exactly (tablewriter draws │ or | borders)
        row() { vikunja user list 2>/dev/null | grep -E '(│|\|) *${user} *(│|\|)' || true; }
        # only on an empty instance: a restored dump brings its own accounts
        if ! grep -qE '^(│|\|) *[0-9]+ ' <<<"$users"; then
          vikunja user create -u ${user} -e xin@ironshark.org \
            -p "$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/password")" \
            || echo "vikunja: could not create ${user} (already there?)" >&2
        fi
        # with the mailer on, new accounts wait for an email confirmation
        if [ -n "$(row)" ] && ! row | grep -q Active; then
          vikunja user change-status --enable ${user}
        fi
      '';
    };

    tn.web.vhosts.tasks = { port = cfg.port; maxBody = "50m"; };   # attachments
  };
}
