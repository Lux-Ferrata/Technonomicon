{ inputs, ... }: {
  # Office suite: OpenCloud (files, web/desktop/phone sync clients) with
  # Collabora Online (LibreOffice in the browser) for editing documents.
  #   https://office.ironshark.org     OpenCloud; login `admin`, sops
  #                                    opencloud-admin-password (make your
  #                                    own user under Admin settings)
  #   https://collabora.ironshark.org  Collabora (opened from OpenCloud)
  #   https://wopi.ironshark.org       OpenCloud's WOPI server, the bridge
  #                                    Collabora loads and saves through
  # Tailnet-only like every Tn-server-web name. Files live on the fast pool
  # (/srv/opencloud, snapshotted by sanoid); /etc/opencloud holds the secrets
  # `opencloud init` generated on first start, so it is persisted.
  flake.nixosModules.Tn-office = { config, lib, pkgs, ... }:
  let
    domain    = config.tn.web.domain;
    office    = "office.${domain}";
    collabora = "collabora.${domain}";
    wopi      = "wopi.${domain}";
    port      = 9200;                 # OpenCloud's proxy
    wopiPort  = 9300;                 # its collaboration (WOPI) service
    coolPort  = 9980;                 # Collabora
    stateDir  = "/srv/opencloud";

    # OpenCloud's default CSP plus Collabora in frames and images
    csp = (pkgs.formats.yaml {}).generate "opencloud-csp.yaml" {
      directives = {
        child-src       = [ "'self'" ];
        connect-src     = [ "'self'" "blob:" "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/" "https://update.opencloud.eu/" ];
        default-src     = [ "'none'" ];
        font-src        = [ "'self'" ];
        frame-ancestors = [ "'self'" ];
        frame-src       = [ "'self'" "blob:" "https://embed.diagrams.net/" "https://${collabora}/" ];
        img-src         = [ "'self'" "data:" "blob:" "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/" "https://${collabora}/" ];
        manifest-src    = [ "'self'" ];
        media-src       = [ "'self'" ];
        object-src      = [ "'self'" "blob:" ];
        script-src      = [ "'self'" "'unsafe-inline'" ];
        style-src       = [ "'self'" "'unsafe-inline'" ];
        worker-src      = [ "'self'" "blob:" ];
      };
    };
  in {
    sops.secrets.opencloud-admin-password = {};
    sops.templates."opencloud.env".content =
      "ADMIN_PASSWORD=${config.sops.placeholder.opencloud-admin-password}\n";

    services.opencloud = {
      enable  = true;
      address = "127.0.0.1";
      inherit port stateDir;
      url     = "https://${office}";
      environmentFile = config.sops.templates."opencloud.env".path;
      environment = {
        OC_INSECURE = "true";          # nginx terminates TLS; backends are local
        PROXY_TLS   = "false";
        PROXY_CSP_CONFIG_FILE_LOCATION = "${csp}";
        OC_LOG_LEVEL = "warn";

        # the WOPI bridge runs inside the main process
        OC_ADD_RUN_SERVICES = "collaboration";
        COLLABORATION_HTTP_ADDR  = "127.0.0.1:${toString wopiPort}";
        COLLABORATION_GRPC_ADDR  = "127.0.0.1:${toString (wopiPort + 1)}";
        COLLABORATION_WOPI_SRC   = "https://${wopi}";
        COLLABORATION_APP_NAME    = "CollaboraOnline";
        COLLABORATION_APP_PRODUCT = "Collabora";
        COLLABORATION_APP_ADDR    = "https://${collabora}";
        COLLABORATION_APP_INSECURE = "false";
        COLLABORATION_CS3API_DATAGATEWAY_INSECURE = "true";
      };
    };

    services.collabora-online = {
      enable = true;
      port   = coolPort;
      settings = {
        server_name = collabora;
        ssl = { enable = false; termination = true; };   # nginx does TLS
        net = {
          listen = "loopback";
          post_allow.host = [ "127\\.0\\.0\\.1" "::1" ];
        };
      };
      # only OpenCloud's WOPI server may open documents here
      aliasGroups = [ { host = "https://${wopi}:443"; } ];
    };

    # data on the fast pool
    systemd.services.opencloud = {
      requires = [ "zfs-mount.service" ];
      after    = [ "zfs-mount.service" ];
    };
    systemd.services.opencloud-init-config = {
      requires = [ "zfs-mount.service" ];
      after    = [ "zfs-mount.service" ];
    };
    environment.persistence."/persist".directories = [
      { directory = "/etc/opencloud"; user = "opencloud"; group = "opencloud"; mode = "0750"; }
    ];

    tn.web.vhosts = {
      office    = { inherit port; maxBody = "10g"; };          # big uploads (chunked anyway)
      wopi      = { port = wopiPort; maxBody = "1g"; };        # document saves
      collabora = {
        port = coolPort;
        maxBody = "1g";
        extraConfig = ''
          proxy_read_timeout 36000s;    # editing sessions are long websockets
        '';
      };
    };
  };
}
