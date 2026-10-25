{ inputs, ... }: {
  # Mimir: long-term practice of procedures (math, physics, AtCoder, sysadmin)
  # next to Anki's facts. PrairieLearn generates a fresh variant of each
  # problem template and grades it; the `mimir` scheduler (_mimir/, FSRS)
  # decides what comes back when. Plan: ~/.claude/plans/i-want-to-build-dazzling-wand.md;
  # how to use it: the Wiki page "Mimir".
  #
  #   learn.ironshark.org  the learner: today's practice (Practice > today)
  #   pl.ironshark.org     the author: question previews, PL's Test button, sync logs
  #
  # PrairieLearn runs in dev mode (PL's own mode for course authors): no
  # login, tailnet-only like every vhost. On learn. nginx adds dev mode's
  # test-user cookie, so every visit there is one fixed non-staff learner and
  # never sees the staff panel's "Show/Hide answer"; pl. is the auto-logged-in
  # author. The course is ~/Projects/Mimir (Syncthing -> /srv/xin/Projects/
  # Mimir), mounted read-only; /srv/mimir/generated is mounted over its empty
  # courseInstances/ and belongs to the scheduler.
  #
  # Every day at 04:00 (the practice day's boundary) `mimir plan` ingests
  # yesterday's submissions into its review log (/srv/mimir/state/mimir.db,
  # the system of record), replays FSRS, writes today's Homework assessment
  # and reloads PL through dev mode's GET /pl/loadFromDisk. Never PL's API
  # course sync: it runs `git clean -fdx` + `git reset --hard` on the course.
  flake.nixosModules.Tn-mimir = { config, lib, pkgs, ... }:
  let
    port   = 3060;
    root   = "/srv/mimir";
    course = "/srv/xin/Projects/Mimir";
    mimir  = pkgs.callPackage ./_mimir/package.nix { };
    image  = mimir.passthru.plImage;
    podman = "${config.virtualisation.podman.package}/bin/podman";
    domain = config.tn.web.domain;

    plConfig = pkgs.writeText "prairielearn-config.json" (builtins.toJSON {
      courseDirs                  = [ "/course" ];
      serverCanonicalHost         = "https://learn.${domain}";
      questionTimeoutMilliseconds = 20000;
    });

    env = {
      MIMIR_COURSE        = course;
      MIMIR_GENERATED     = "${root}/generated";
      MIMIR_STATE         = "${root}/state";
      MIMIR_PL_URL        = "http://127.0.0.1:${toString port}";
      MIMIR_PL_TOKEN_FILE = config.sops.secrets.mimir-pl-token.path;
      MIMIR_TZ            = config.time.timeZone;
      MIMIR_LEARN_URL     = "https://learn.${domain}";
      MIMIR_AUTHOR_URL    = "https://pl.${domain}";
    };

    # `mimir` for xin's shell on Akmon, with the service's settings
    mimirCli = pkgs.symlinkJoin {
      name = "mimir-akmon";
      paths = [ mimir ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/mimir ${lib.concatStringsSep " "
          (lib.mapAttrsToList (k: v: "--set-default ${k} ${lib.escapeShellArg v}") env)}
      '';
    };
  in {
    # PL's personal access token for mimir: random, in sops; its hash is
    # put into PL's database by mimir-pl-token below
    sops.secrets.mimir-pl-token = { owner = "xin"; };

    systemd.tmpfiles.rules = [
      "d ${root}           0755 root root  -"
      "d ${root}/postgres  0700 root root  -"   # the container's postgres takes it over
      "d ${root}/generated 0755 xin  users -"
      "d ${root}/state     0755 xin  users -"
      "d /srv/backup/mimir 0750 root root  -"
    ];

    # ── PrairieLearn ────────────────────────────────────────────────────
    virtualisation.oci-containers.containers.prairielearn = {
      inherit image;
      ports   = [ "127.0.0.1:${toString port}:3000" ];
      volumes = [
        "${course}:/course:ro"
        "${root}/generated:/course/courseInstances:ro"
        "${root}/postgres:/var/postgres"
        "${plConfig}:/PrairieLearn/config.json:ro"
      ];
    };
    systemd.services.podman-prairielearn = {
      requires = [ "srv-xin.service" ];   # the course is a Syncthing folder
      after    = [ "srv-xin.service" ];
      # PL's init.sh (PID 1) ignores SIGTERM, so podman would SIGKILL it and
      # Postgres would need crash recovery. Stop Postgres cleanly first; PL
      # exits with it.
      preStop = lib.mkBefore ''
        ${podman} exec prairielearn su postgres -c 'pg_ctl -D /var/postgres stop -m fast' || true
      '';
    };

    systemd.services.mimir-pl-token = {
      description = "Give mimir its PrairieLearn API token";
      after    = [ "podman-prairielearn.service" ];
      requires = [ "podman-prairielearn.service" ];
      wantedBy = [ "podman-prairielearn.service" ];
      path = [ pkgs.curl pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = "token:${config.sops.secrets.mimir-pl-token.path}";
      };
      script = ''
        for i in $(seq 1 150); do
          curl -sf http://127.0.0.1:${toString port}/pl/webhooks/ping >/dev/null && break
          sleep 2
        done
        hash=$(tr -d '\n' < "$CREDENTIALS_DIRECTORY/token" | sha256sum | cut -d' ' -f1)
        ${podman} exec -i prairielearn psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q <<SQL
        INSERT INTO users (uid, name) VALUES ('dev@example.com', 'Dev User') ON CONFLICT (uid) DO NOTHING;
        INSERT INTO access_tokens (user_id, name, token_hash)
          SELECT id, 'mimir', '$hash' FROM users WHERE uid = 'dev@example.com'
          ON CONFLICT (token_hash) DO NOTHING;
        SQL
      '';
    };

    # ── the scheduler ───────────────────────────────────────────────────
    systemd.services.mimir-plan = {
      description = "Plan today's Mimir practice";
      after    = [ "mimir-pl-token.service" ];
      requires = [ "mimir-pl-token.service" ];
      environment = env;
      serviceConfig = {
        Type = "oneshot";
        User = "xin";
        Group = "users";
        ExecStart = "${mimir}/bin/mimir plan";
      };
    };
    systemd.timers.mimir-plan = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = "*-*-* 04:00:00"; Persistent = true; };
    };

    # ── backups (on top of sanoid's snapshots of /srv) ──────────────────
    # dumps are clean where a snapshot of a live database is only crash-consistent
    systemd.services.mimir-backup = {
      description = "Dump PrairieLearn's database and copy Mimir's review log";
      after = [ "podman-prairielearn.service" ];
      path = [ pkgs.zstd pkgs.sqlite pkgs.findutils pkgs.coreutils ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        day=$(date +%F)
        ${podman} exec prairielearn pg_dump -U postgres -d postgres | zstd -q -o /srv/backup/mimir/prairielearn-$day.sql.zst.tmp
        mv /srv/backup/mimir/prairielearn-$day.sql.zst.tmp /srv/backup/mimir/prairielearn-$day.sql.zst
        if [ -f ${root}/state/mimir.db ]; then
          sqlite3 ${root}/state/mimir.db ".backup '/srv/backup/mimir/mimir-$day.db'"
        fi
        find /srv/backup/mimir -type f -mtime +30 -delete
      '';
    };
    systemd.timers.mimir-backup = {
      wantedBy = [ "timers.target" ];
      # after the shared Postgres dump (02:15), clear of the weekly job (Wed 03:00)
      timerConfig = { OnCalendar = "*-*-* 02:20:00"; Persistent = true; };
    };

    # ── web ─────────────────────────────────────────────────────────────
    tn.web.vhosts.learn = {
      inherit port;
      # replaces the default "/" location; the cookie must be set here, since a
      # location's own proxy_set_header drops the inherited ones
      locations."/" = {
        proxyPass       = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        extraConfig     = ''proxy_set_header Cookie "pl_test_user=test_student; $http_cookie";'';
      };
    };
    tn.web.vhosts.pl = { inherit port; };

    environment.systemPackages = [ mimirCli ];
  };
}
