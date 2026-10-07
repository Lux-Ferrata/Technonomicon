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

    services.paperless = {
      enable         = true;
      dataDir        = "/srv/paperless";
      passwordFile   = config.sops.secrets.paperless-admin-password.path;
      database.createLocally = true;
      configureTika  = true;
      exporter.enable = true;   # 01:30, into ${cfg.dataDir}/export
      settings = {
        PAPERLESS_URL          = "https://docs.ironshark.org";
        PAPERLESS_ADMIN_USER   = "xin";
        PAPERLESS_ADMIN_MAIL   = "xin@ironshark.org";
        PAPERLESS_TIME_ZONE    = config.time.timeZone;
        PAPERLESS_OCR_LANGUAGE = "eng+chi_sim";
        # scans from `scan` arrive already OCR'd: keep their text layer
        PAPERLESS_OCR_MODE     = "skip";
        PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
      };
    };

    tn.web.vhosts.docs = { port = cfg.port; maxBody = "200m"; };
  };
}
