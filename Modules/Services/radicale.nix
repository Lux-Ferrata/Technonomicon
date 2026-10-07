{ inputs, ... }: {
  # Radicale (CalDAV/CardDAV) at https://cal.ironshark.org, user xin.
  #   clients (DAVx5, khal, Obsidian Full Calendar): https://cal.ironshark.org/
  #   web calendar (InfCloud):                       https://cal.ironshark.org/infcloud/
  #   Radicale's own page (make/import/export):      https://cal.ironshark.org/.web/
  # Collections live on the fast pool (/srv/radicale, snapshotted).
  # Calendars listed in tn.calendarPush also go to Google (calendar-push.nix).
  flake.nixosModules.Tn-radicale = { config, lib, pkgs, ... }:
  let
    port  = 5232;
    store = "/srv/radicale/collections";

    # static CalDAV web client (AGPL), not in nixpkgs. Pointed at Radicale on
    # the same origin, so the principal is https://cal.ironshark.org/<user>/.
    infcloud = pkgs.stdenvNoCC.mkDerivation {
      pname   = "infcloud";
      version = "0.13.1";
      src = pkgs.fetchurl {
        url  = "https://www.inf-it.com/InfCloud_0.13.1.zip";
        hash = "sha256-n6le3S3MK4ZKELUDq5IgiV6ijUxVQasCEX3hUR1UZNQ=";
      };
      nativeBuildInputs = [ pkgs.unzip ];
      unpackPhase = "unzip -q $src";
      installPhase = ''
        cp -r infcloud $out
        cd $out
        # Radicale at the origin's root, not the default /caldav.php/
        substituteInPlace config.js \
          --replace-fail "location.pathname.replace(RegExp('/+[^/]+/*(index\.html)?\$'),'')+
		'/caldav.php/'," "'/'," \
          --replace-fail "var globalTimeZone='Europe/Berlin';" "var globalTimeZone='${config.time.timeZone}';"
        # appcache (removed from browsers) would only serve stale copies
        sed -i 's/ manifest="cache.manifest"//' index.html
      '';
    };
  in {
    sops.secrets.radicale-htpasswd = { owner = "radicale"; };

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = [ "127.0.0.1:${toString port}" ];
        auth = {
          type                = "htpasswd";
          htpasswd_filename   = config.sops.secrets.radicale-htpasswd.path;
          htpasswd_encryption = "bcrypt";
        };
        storage.filesystem_folder = store;
      };
    };
    systemd.services.radicale = {
      requires = [ "zfs-mount.service" ];
      after    = [ "zfs-mount.service" ];
    };
    systemd.tmpfiles.rules = [
      "d /srv/radicale 0750 radicale radicale -"
      "d ${store}      0750 radicale radicale -"
    ];

    tn.web.vhosts.cal = {
      inherit port;
      maxBody   = "50m";   # whole-calendar .ics imports
      locations."/infcloud/".alias = "${infcloud}/";
    };
  };
}
