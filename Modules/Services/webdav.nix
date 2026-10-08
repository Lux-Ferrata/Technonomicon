{ inputs, ... }: {
  # Plain WebDAV at https://dav.ironshark.org, for Zotero's attachment sync
  # (Zotero > Settings > Sync > Files: WebDAV, URL dav.ironshark.org, user
  # zotero; Zotero adds the /zotero/ folder itself). Item metadata keeps
  # syncing through zotero.org. Also Super Productivity's sync (Kvasir:
  # Settings > Sync > WebDAV, URL https://dav.ironshark.org/, user tasks,
  # password from sops webdav-tasks-password; the user only sees
  # /srv/webdav/tasks). Files live on the fast pool (/srv/webdav),
  # snapshotted by sanoid.
  flake.nixosModules.Tn-webdav = { config, lib, pkgs, ... }:
  let
    root = "/srv/webdav";
    port = 8090;
  in {
    sops.secrets.webdav-zotero-password = {};
    sops.secrets.webdav-tasks-password  = {};
    sops.templates."webdav.env".content = ''
      ZOTERO_PASSWORD=${config.sops.placeholder.webdav-zotero-password}
      TASKS_PASSWORD=${config.sops.placeholder.webdav-tasks-password}
    '';

    services.webdav = {
      enable = true;
      environmentFile = config.sops.templates."webdav.env".path;
      settings = {
        address     = "127.0.0.1";
        inherit port;
        directory   = root;
        permissions = "none";   # nothing without a login
        behindProxy = true;
        users = [ {
          username    = "zotero";
          password    = "{env}ZOTERO_PASSWORD";
          permissions = "CRUD";
        } {
          username    = "tasks";
          password    = "{env}TASKS_PASSWORD";
          directory   = "${root}/tasks";
          permissions = "CRUD";
        } ];
      };
    };
    systemd.services.webdav = {
      requires = [ "zfs-mount.service" ];
      after    = [ "zfs-mount.service" ];
    };
    systemd.tmpfiles.rules = [
      "d ${root}        0750 webdav webdav -"
      "d ${root}/zotero 0750 webdav webdav -"
      "d ${root}/tasks  0750 webdav webdav -"
    ];

    tn.web.vhosts.dav = { inherit port; maxBody = "1g"; };   # big PDFs
  };
}
