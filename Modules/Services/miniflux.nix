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
        # read and unread entries both go 30 days after they arrive, so no
        # backlog builds up; starred entries are never removed (star
        # anything to keep)
        CLEANUP_ARCHIVE_READ_DAYS = 30;
        CLEANUP_ARCHIVE_UNREAD_DAYS = 30;
      };
    };

    # Feeds for sites that publish none (Nature Futures, ...): a scraper
    # writes Atom files every 6 h, served at https://rss.ironshark.org/scraped/
    # and subscribed to in Miniflux with the crawler on. Not persisted: the
    # first run after boot rewrites them.
    users.users.feed-scrapers = { isSystemUser = true; group = "feed-scrapers"; };
    users.groups.feed-scrapers = {};
    systemd.services.feed-scrapers = {
      description = "Write Atom feeds for sites without one";
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      startAt  = "00/6:20";
      serviceConfig = {
        Type  = "oneshot";
        User  = "feed-scrapers";
        StateDirectory     = "feed-scrapers";
        StateDirectoryMode = "0755";   # nginx reads it
        ExecStart = "${pkgs.python3.withPackages (p: [ p.beautifulsoup4 ])}/bin/python3 ${./_feed-scrapers.py} /var/lib/feed-scrapers";
      };
    };

    tn.web.vhosts.rss = {
      inherit port;
      maxBody = "10m";
      locations."/scraped/" = {
        alias = "/var/lib/feed-scrapers/";
        extraConfig = "types { application/atom+xml xml; }";
      };
    };
  };
}
