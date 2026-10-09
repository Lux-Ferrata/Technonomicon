{ inputs, ... }: {
  # AstraDraw at https://draw.ironshark.org: Excalidraw with workspaces, live
  # collaboration and presentations (github.com/AstraDraw/astradraw, MIT; an
  # alpha hobby project, quiet since 2025-12). Kvasir's launcher calls it
  # "Flowchart". Log in as xin, password sops astradraw-admin-password;
  # sign-ups are off (one user).
  #
  # Upstream ships only container images, so the three app parts run under
  # podman, pinned by digest; what they stand on is native:
  #   app       127.0.0.1:3040  nginx serving the page            (/)
  #   room      127.0.0.1:3041  socket.io relay for collaboration (/socket.io/)
  #   api       127.0.0.1:3042  NestJS API                        (/api/v2/)
  #                             host network: Postgres and MinIO are localhost-only
  #   Postgres  the shared one: database and role astradraw, password over TCP
  #   MinIO     127.0.0.1:9010  scenes and files on the fast pool; thumbnails
  #                             are public-read, served at /s3/
  flake.nixosModules.Tn-astradraw = { config, lib, pkgs, ... }:
  let
    url    = "https://draw.${config.tn.web.domain}";
    ports  = { app = 3040; room = 3041; api = 3042; minio = 9010; };
    s3     = "http://127.0.0.1:${toString ports.minio}";
    bucket = "excalidraw";
    srv    = "/srv/astradraw";
    image  = name: digest: "docker.io/astradraw/${name}:1.0.1@sha256:${digest}";
    ph     = config.sops.placeholder;
  in {
    sops.secrets = {
      astradraw-jwt-secret     = {};
      astradraw-db-password    = {};
      astradraw-minio-password = {};
      astradraw-admin-password = {};
    };
    sops.templates."astradraw-minio.env".content = ''
      MINIO_ROOT_USER=astradraw
      MINIO_ROOT_PASSWORD=${ph.astradraw-minio-password}
    '';
    # read by podman (root) into the api's environment: the image runs as
    # uid 1000, which couldn't open root-only secret files
    sops.templates."astradraw-api.env".content = ''
      DATABASE_URL=postgresql://astradraw:${ph.astradraw-db-password}@127.0.0.1:5432/astradraw?schema=public
      S3_ACCESS_KEY=astradraw
      S3_SECRET_KEY=${ph.astradraw-minio-password}
      JWT_SECRET=${ph.astradraw-jwt-secret}
      ADMIN_PASSWORD=${ph.astradraw-admin-password}
    '';

    # ── blobs: MinIO on the fast pool ────────────────────────────────────
    services.minio = {
      enable              = true;
      listenAddress       = "127.0.0.1:${toString ports.minio}";
      consoleAddress      = "127.0.0.1:${toString (ports.minio + 1)}";
      browser             = false;
      dataDir             = [ "${srv}/minio" ];
      configDir           = "${srv}/minio-config";
      certificatesDir     = "${srv}/minio-certs";
      rootCredentialsFile = config.sops.templates."astradraw-minio.env".path;
    };
    systemd.services.minio.unitConfig.RequiresMountsFor = [ srv ];

    # the bucket, thumbnails readable without a login (the page shows them
    # as plain image URLs under /s3/)
    systemd.services.astradraw-bucket = {
      description = "Create AstraDraw's MinIO bucket";
      after       = [ "minio.service" ];
      requires    = [ "minio.service" ];
      path        = [ pkgs.minio-client ];
      environment.MC_CONFIG_DIR = "/run/astradraw-bucket";
      serviceConfig = {
        Type             = "oneshot";
        RemainAfterExit  = true;
        DynamicUser      = true;
        RuntimeDirectory = "astradraw-bucket";
        LoadCredential   = "minio:${config.sops.secrets.astradraw-minio-password.path}";
        Restart          = "on-failure";   # MinIO may still be starting
        RestartSec       = 10;
      };
      # the alias comes from the environment, so the key never hits argv
      script = ''
        MC_HOST_local="http://astradraw:$(cat "$CREDENTIALS_DIRECTORY/minio")@127.0.0.1:${toString ports.minio}"
        export MC_HOST_local
        mc mb --ignore-existing local/${bucket}
        mc anonymous set download local/${bucket}/thumbnails
      '';
    };

    # ── metadata: the shared Postgres ────────────────────────────────────
    services.postgresql = {
      ensureDatabases = [ "astradraw" ];
      ensureUsers     = [ { name = "astradraw"; ensureDBOwnership = true; } ];
    };
    # the api logs in over TCP with a password (peer auth needs a host user)
    systemd.services.astradraw-db-password = {
      description = "Set AstraDraw's Postgres password";
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
          STORAGE_BACKEND     = "s3";
          S3_ENDPOINT         = s3;
          S3_BUCKET           = bucket;
          S3_REGION           = "us-east-1";
          S3_FORCE_PATH_STYLE = "true";
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
      after    = [ "astradraw-db-password.service" "astradraw-bucket.service" ];
      requires = [ "astradraw-db-password.service" "astradraw-bucket.service" ];
    };

    tn.web.vhosts.draw = {
      port = ports.app;
      locations = {
        "/socket.io/" = { proxyPass = "http://127.0.0.1:${toString ports.room}"; proxyWebsockets = true; };
        "/api/v2/"    = { proxyPass = "http://127.0.0.1:${toString ports.api}"; };
        # /s3/<bucket>/thumbnails/... -> MinIO, with /s3 stripped
        "/s3/"        = { proxyPass = "${s3}/"; };
      };
    };
  };
}
