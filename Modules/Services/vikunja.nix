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

    # ── offline task list check ───────────────────────────────────────────
    # Thunderbird on Kvasir caches the projects in _vikunja-projects.nix. A
    # project made (or deleted) in Vikunja since then becomes a self-reported
    # issue; Claude's review labels it for the overnight agent, whose PR
    # edits that file. Resolves itself once the list matches again.
    systemd.services.vikunja-projects-check = let
      known = pkgs.writeText "vikunja-projects.json"
        (builtins.toJSON (import ./_vikunja-projects.nix));
    in {
      description = "Check Thunderbird's offline task list against Vikunja";
      after    = [ "vikunja.service" ];
      requires = [ "vikunja.service" ];
      path = with pkgs; [ curl jq coreutils config.tn.alerts.issuePackage ];
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = "password:${config.sops.secrets.vikunja-password.path}";
      };
      script = ''
        api=http://127.0.0.1:${toString cfg.port}/api/v1
        tok=$(jq -nc --arg p "$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/password")" '{username: "${user}", password: $p}' \
              | curl -sf -X POST "$api/login" -H 'Content-Type: application/json' -d @- | jq -r .token)
        live=$(curl -sf -H "Authorization: Bearer $tok" "$api/projects?per_page=200" \
               | jq -c '[.[] | select(.is_archived | not) | select(.id > 0) | {id, title}]')

        # in Vikunja, not in the list
        jq -r --slurpfile k ${known} '.[] | select(.id as $i | [$k[0][]] | index($i) | not) | "\(.id)\t\(.title)"' <<<"$live" |
        while IFS=$'\t' read -r id title; do
          printf 'Vikunja project "%s" (id %s) is not in Thunderbird'"'"'s offline task list, so it is not available offline on Kvasir.\n\nFix: add this line to Modules/Services/_vikunja-projects.nix, then deploy Kvasir:\n\n    "%s" = %s;\n' \
            "$title" "$id" "$title" "$id" > /tmp/vikunja-body
          tn-issue report "vikunja-project:$id" digest "Vikunja project '$title' isn't available offline yet" /tmp/vikunja-body
        done

        # in the list, gone from Vikunja (deleted or archived)
        jq -r --argjson live "$live" 'to_entries[] | select(.value as $i | [$live[].id] | index($i) | not) | "\(.value)\t\(.key)"' ${known} |
        while IFS=$'\t' read -r id title; do
          printf 'Thunderbird still lists Vikunja project "%s" (id %s), which no longer exists (or is archived).\n\nFix: remove its line from Modules/Services/_vikunja-projects.nix, then deploy Kvasir.\n' \
            "$title" "$id" > /tmp/vikunja-body
          tn-issue report "vikunja-stale:$id" digest "Thunderbird lists a Vikunja project that's gone: '$title'" /tmp/vikunja-body
        done

        # everything that matches now: resolve any earlier report
        for id in $(jq -r '.[].id' <<<"$live"); do
          jq -e --argjson i "$id" '[.[]] | index($i)' ${known} >/dev/null && tn-issue resolve "vikunja-project:$id"
        done
        for id in $(jq -r '.[]' ${known}); do
          jq -e --argjson i "$id" '[.[].id] | index($i)' <<<"$live" >/dev/null && tn-issue resolve "vikunja-stale:$id"
        done
        rm -f /tmp/vikunja-body
      '';
    };
    systemd.timers.vikunja-projects-check = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "05:20";   # before Claude's 05:40 review
    };
  };
}
