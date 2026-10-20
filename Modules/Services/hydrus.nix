{ inputs, ... }: {
  # Hydrus at https://hydrus.ironshark.org: the image library -- collected
  # images, screenshots, art references, gifs -- searched by exact tags
  # (hydrusnetwork.github.io, WTFPL). Immich keeps the user's own photos;
  # this is for what they save from elsewhere.
  #
  # Hydrus is a desktop (Qt) client with its own SQLite database, so it runs
  # here in upstream's container image, which wraps the client in a
  # VNC-in-the-browser desktop:
  #   hydrus.      -> 127.0.0.1:5800   noVNC (/vnc.html), the client's GUI
  #   hydrus-api.  -> 127.0.0.1:45869  the Client API, for Hydrus Companion
  #                                    (browser) and Hydrus Web (phone)
  # Tailnet-only like every vhost; the noVNC page has no login of its own.
  # The Client API is off until it's turned on in the GUI (services > edit
  # > client api: port 45869, "allow non-local connections", "support
  # CORS" for Hydrus Web), and each app gets an access key in services >
  # review > client api.
  #
  # The database and the files it holds live in /srv/hydrus (snapshotted by
  # sanoid). The image runs as uid 1000 = xin and never chowns its db
  # folder, hence the owner below.
  #
  # Inbox: the Syncthing folder "Hydrus_Inbox" (Kvasir ~/Hydrus_Inbox, the
  # phone, Akmon /srv/xin/HydrusInbox) is mounted at /opt/hydrus/inbox. A
  # Hydrus import folder on that path, set to delete files after a
  # successful import, empties it, and the deletions sync back.
  flake.nixosModules.Tn-hydrus = { config, lib, pkgs, ... }:
  let
    ports = { vnc = 5800; api = 45869; };
    data  = "/srv/hydrus";
    inbox = "/srv/xin/HydrusInbox";
  in {
    systemd.tmpfiles.rules = [ "d ${data} 0700 xin users -" ];

    virtualisation.oci-containers.containers.hydrus = {
      image = "ghcr.io/hydrusnetwork/hydrus:v689@sha256:6ec992feafb893948a2cca1b51a28f945213368dc94091ab9c0a759063d43ebc";
      ports = [
        "127.0.0.1:${toString ports.vnc}:5800"
        "127.0.0.1:${toString ports.api}:45869"
      ];
      volumes = [
        "${data}:/opt/hydrus/db"
        "${inbox}:/opt/hydrus/inbox"
      ];
      environment = {
        UID = "1000";
        GID = "1000";   # upstream: GID is fixed to 1000 for now
        TZ  = config.time.timeZone;
      };
      extraOptions = [ "--tmpfs=/tmp" ];
    };

    # the inbox is a Syncthing folder, made by Tn-dev-host's srv-xin
    systemd.services.podman-hydrus = {
      requires = [ "srv-xin.service" ];
      after    = [ "srv-xin.service" ];
    };

    tn.web.vhosts.hydrus       = { port = ports.vnc; maxBody = "1g"; };
    tn.web.vhosts."hydrus-api" = { port = ports.api; maxBody = "1g"; };
  };
}
