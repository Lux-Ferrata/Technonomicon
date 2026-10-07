{ inputs, ... }: {
  # Immich at https://photos.ironshark.org: search images by description,
  # faces and text in them. It indexes ~/Media (Syncthing's copy at
  # /srv/xin/Media) as a read-only external library, mounted at /mnt/media
  # (Administration > External Libraries > import path /mnt/media). Its own
  # library (uploads, Takeout imports) and thumbnails are in /srv/immich.
  #
  # Machine learning runs on the CPU: models load on demand and unload when
  # idle, and the GPU stays with code completion.
  flake.nixosModules.Tn-immich = { config, lib, pkgs, ... }:
  let
    cfg = config.services.immich;
    media = "/srv/immich";
  in {
    services.immich = {
      enable        = true;
      host          = "127.0.0.1";
      port          = 2283;
      mediaLocation = media;
      accelerationDevices = [];   # CPU only
      machine-learning.environment.MACHINE_LEARNING_MODEL_TTL = "300";
    };

    systemd.services.immich-server = {
      unitConfig.RequiresMountsFor = [ media "/srv/xin/Media" ];
      serviceConfig = {
        # /srv/xin is xin:users 0750
        SupplementaryGroups = [ "users" ];
        BindReadOnlyPaths   = [ "/srv/xin/Media:/mnt/media" ];
      };
    };
    systemd.tmpfiles.rules = [ "d ${media} 0750 ${cfg.user} ${cfg.group} -" ];

    tn.web.vhosts.photos = { port = cfg.port; maxBody = "50000m"; };   # videos
  };
}
