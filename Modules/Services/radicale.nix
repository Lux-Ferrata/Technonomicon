{ inputs, ... }: {
  # Radicale (CalDAV) at https://cal.ironshark.org, user xin: only the staging
  # area for calendars Akmon generates (Vikunja due dates,
  # task-deadlines.nix), which calendar-push.nix mirrors to Google Calendar.
  # Calendars are made and edited in Google itself, not here.
  # Radicale's own page (inspect/export): https://cal.ironshark.org/.web/
  # Collections live on the fast pool (/srv/radicale, snapshotted).
  flake.nixosModules.Tn-radicale = { config, lib, pkgs, ... }:
  let
    port  = 5232;
    store = "/srv/radicale/collections";
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
      maxBody   = "50m";   # whole-calendar .ics uploads
    };
  };
}
