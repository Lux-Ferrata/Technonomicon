{ inputs, ... }: {
  # AstraDraw at https://draw.ironshark.org: Excalidraw with workspaces, live
  # collaboration and presentations (github.com/AstraDraw/astradraw, MIT; an
  # alpha hobby project, quiet since 2025-12). Kvasir's launcher calls it
  # "Flowchart". Log in as xin, password sops astradraw-admin-password;
  # sign-ups are off (one user).
  #
  # Upstream ships only container images, so the three app parts run under
  # podman, pinned by digest:
  #   app   127.0.0.1:3040  nginx serving the page            (/)
  #   room  127.0.0.1:3041  socket.io relay for collaboration (/socket.io/)
  #   api   127.0.0.1:3042  NestJS API                        (/api/v2/)
  #                         host network, to reach Postgres on localhost
  # Everything it stores (users, scenes, files, thumbnails) goes in the
  # shared Postgres -- its keyv storage mode -- so the nightly dumps and
  # snapshots cover it and there is no object store to run. (Upstream's
  # default is MinIO, which nixpkgs refuses: abandoned, unfixed CVEs.)
  flake.nixosModules.Tn-astradraw = { config, lib, pkgs, ... }:
  let
    url   = "https://draw.${config.tn.web.domain}";
    ports = { app = 3040; room = 3041; api = 3042; };
    api   = "http://127.0.0.1:${toString ports.api}";
    image = name: digest: "docker.io/astradraw/${name}:1.0.1@sha256:${digest}";
    db    = "postgresql://astradraw:${config.sops.placeholder.astradraw-db-password}@127.0.0.1:5432/astradraw";
  in {
    sops.secrets = {
      astradraw-jwt-secret     = {};
      astradraw-db-password    = {};
      astradraw-admin-password = {};
    };
    # read by podman (root) into the api's environment: the image runs as
    # uid 1000, which couldn't open root-only secret files
    sops.templates."astradraw-api.env".content = ''
      DATABASE_URL=${db}?schema=public
      STORAGE_URI=${db}
      JWT_SECRET=${config.sops.placeholder.astradraw-jwt-secret}
      ADMIN_PASSWORD=${config.sops.placeholder.astradraw-admin-password}
    '';

    # ── the shared Postgres ─────────────────────────────────────────────
    services.postgresql = {
      ensureDatabases = [ "astradraw" ];
      ensureUsers     = [ { name = "astradraw"; ensureDBOwnership = true; } ];
    };
    # The api logs in over TCP with a password (peer auth needs a host user).
    # The key-value table is made here too: on startup the api's four storage
    # namespaces race to create it, and @keyv/postgres leaves each loser
    # broken (every query throws) until the next restart.
    systemd.services.astradraw-db-setup = {
      description = "Prepare AstraDraw's Postgres role and table";
      after       = [ "postgresql-setup.service" ];
      requires    = [ "postgresql-setup.service" ];
      path        = [ config.services.postgresql.package ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = "postgres";
        LoadCredential  = "pw:${config.sops.secrets.astradraw-db-password.path}";
      };
      # SQL on stdin, not argv; the password is hex, so it needs no quoting
      script = ''
        printf "ALTER ROLE astradraw WITH PASSWORD '%s';\n" "$(cat "$CREDENTIALS_DIRECTORY/pw")" \
          | psql -v ON_ERROR_STOP=1 -q -d postgres
        psql -v ON_ERROR_STOP=1 -q -d astradraw <<'SQL'
        CREATE TABLE IF NOT EXISTS public.keyv(key VARCHAR(255) PRIMARY KEY, value TEXT);
        ALTER TABLE public.keyv OWNER TO astradraw;
        SQL
      '';
    };

    # ── the app: upstream's images, pinned ───────────────────────────────
    virtualisation.oci-containers.containers = {
      astradraw-app = {
        image = image "app" "ce6261a39e5bfc377f17938b53126267744115f08a7d35e859059bba5bf48ae8";
        ports = [ "127.0.0.1:${toString ports.app}:80" ];
        # turned into the page's runtime config when the container starts
        environment = {
          VITE_APP_WS_SERVER_URL            = url;
          VITE_APP_BACKEND_V2_GET_URL       = "${url}/api/v2/scenes/";
          VITE_APP_BACKEND_V2_POST_URL      = "${url}/api/v2/scenes/";
          VITE_APP_STORAGE_BACKEND          = "http";
          VITE_APP_HTTP_STORAGE_BACKEND_URL = "${url}/api/v2";
          VITE_APP_FIREBASE_CONFIG          = "";
          VITE_APP_DISABLE_TRACKING         = "true";
        };
      };
      astradraw-room = {
        image = image "room" "7cff5ef3a367eab1c39d51d00a9cd10366e1eade6aa408e531376359c8beea05";
        ports = [ "127.0.0.1:${toString ports.room}:80" ];
        environment = { PORT = "80"; CORS_ORIGIN = url; };
      };
      astradraw-api = {
        image = image "api" "ab71911363b1dcafb35e737570bf642e1ae3e8cf9b4286a51183584ee20ee2ba";
        extraOptions = [ "--network=host" ];
        environment = {
          NODE_ENV            = "production";   # secure cookies (nginx serves https)
          PORT                = toString ports.api;
          APP_URL             = url;
          STORAGE_BACKEND     = "keyv";
          ENABLE_LOCAL_AUTH   = "true";
          ENABLE_REGISTRATION = "false";
          ADMIN_USERNAME      = "xin";
          ADMIN_EMAIL         = "xin@ironshark.org";
          SUPERADMIN_EMAILS   = "xin@ironshark.org";
          OIDC_CALLBACK_URL   = "${url}/api/v2/auth/callback";
        };
        environmentFiles = [ config.sops.templates."astradraw-api.env".path ];
      };
    };
    systemd.services.podman-astradraw-api = {
      after    = [ "astradraw-db-setup.service" ];
      requires = [ "astradraw-db-setup.service" ];
    };

    tn.web.vhosts.draw = {
      port = ports.app;
      locations = {
        "/socket.io/" = { proxyPass = "http://127.0.0.1:${toString ports.room}"; proxyWebsockets = true; };
        "/api/v2/"    = { proxyPass = api; };
        # Scenes record their thumbnail as /s3/<bucket>/thumbnails/<id>.png,
        # an object-store URL; with keyv storage the api serves it instead
        # (the login cookie comes along with the image request)
        "~ ^/s3/excalidraw/thumbnails/(?<scene>[A-Za-z0-9_-]+)\\.png$" = {
          proxyPass = "${api}/api/v2/workspace/scenes/$scene/thumbnail";
        };
      };
    };
  };
}
