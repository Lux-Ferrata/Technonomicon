{ inputs, ... }: {
  # Miniflux (RSS) at https://rss.ironshark.org, user xin, on the shared
  # Postgres. Feeds and read state live here, so every device agrees:
  # the phone through a Miniflux/Fever/Google Reader client (Read You,
  # Capy Reader), Kvasir through the web page or NewsFlash.
  flake.nixosModules.Tn-miniflux = { config, lib, pkgs, ... }:
  let
    port = 8070;
  in {
    sops.secrets.miniflux-password = {};
    sops.templates."miniflux-admin.env".content = ''
      ADMIN_USERNAME=xin
      ADMIN_PASSWORD=${config.sops.placeholder.miniflux-password}
    '';

    services.miniflux = {
      enable = true;
      adminCredentialsFile = config.sops.templates."miniflux-admin.env".path;
      config = {
        LISTEN_ADDR = "127.0.0.1:${toString port}";
        BASE_URL    = "https://rss.ironshark.org/";
        POLLING_FREQUENCY = 30;      # minutes
        CLEANUP_ARCHIVE_READ_DAYS = 365;
        # unread entries go 30 days after they arrive, so no backlog builds
        # up; starred entries are never removed (star anything to keep)
        CLEANUP_ARCHIVE_UNREAD_DAYS = 30;
      };
    };

    tn.web.vhosts.rss = { inherit port; maxBody = "10m"; };
  };
}
