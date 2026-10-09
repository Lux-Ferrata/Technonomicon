{ inputs, ... }: {
  # Paperless-ngx at https://docs.ironshark.org (user xin), on the shared
  # Postgres. Documents come in through the REST API, not a synced consume
  # folder: Kvasir's `paperless-add FILE...` and `scan --paperless`
  # (Tn-scan), or the phone app. OCR in English and Simplified Chinese;
  # Tika + Gotenberg read Office files and emails.
  # Data on the fast pool (/srv/paperless, snapshotted) plus a nightly
  # exporter dump (/srv/paperless/export), a plain-file copy of everything.
  flake.nixosModules.Tn-paperless = { config, lib, pkgs, ... }:
  let
    cfg = config.services.paperless;
  in {
    sops.secrets.paperless-admin-password = {};

    # configureTika brings Gotenberg, whose default port is Forgejo's 3000:
    # whichever starts first after a boot wins, and on 2026-10-07 it was
    # Gotenberg (Forgejo down after the 06:00 auto-upgrade reboot)
    services.gotenberg.port = 3070;

    services.paperless = {
      enable         = true;
      dataDir        = "/srv/paperless";
      passwordFile   = config.sops.secrets.paperless-admin-password.path;
      database.createLocally = true;
      configureTika  = true;
      exporter.enable = true;   # 01:30, into ${cfg.dataDir}/export
      # Set here, not in settings: there the module rebuilds tesseract (and
      # so Paperless, test suite and all) with only those languages. The
      # stock package already has every language and comes from the cache.
      environmentFile = pkgs.writeText "paperless-ocr.env" ''
        PAPERLESS_OCR_LANGUAGE=eng+chi_sim
      '';
      settings = {
        PAPERLESS_URL          = "https://docs.ironshark.org";
        PAPERLESS_ADMIN_USER   = "xin";
        PAPERLESS_ADMIN_MAIL   = "xin@ironshark.org";
        PAPERLESS_TIME_ZONE    = config.time.timeZone;
        # scans from `scan` arrive already OCR'd: keep their text layer
        PAPERLESS_OCR_MODE     = "skip";
        PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
      };
    };

    # its task queue (Redis) would otherwise be emptied by every boot
    environment.persistence."/persist".directories = [
      { directory = "/var/lib/redis-paperless"; user = "redis-paperless"; group = "redis-paperless"; mode = "0700"; }
    ];

    tn.web.vhosts.docs = { port = cfg.port; maxBody = "200m"; };
  };
}
