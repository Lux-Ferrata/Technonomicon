{ inputs, ... }: {
  # Karakeep at https://keep.ironshark.org: saved links with a readable copy,
  # screenshot and full offline archive of each page, full-text search
  # (Meilisearch), and tags written by the local chat model (Akmon's :8011,
  # woken on demand) -- nothing leaves the box. Clients: the Brave extension
  # and the phone app, server https://keep.ironshark.org.
  #
  # The first account made becomes the admin. Data is on the fast pool
  # (/srv/karakeep, bound over /var/lib/karakeep).
  flake.nixosModules.Tn-karakeep = { config, lib, pkgs, ... }:
  let
    port = 3010;   # its default 3000 is Forgejo's
    data = "/srv/karakeep";
    onSrv = {
      unitConfig.RequiresMountsFor = [ data ];
      serviceConfig.BindPaths = [ "${data}:/var/lib/karakeep" ];
    };
  in {
    services.karakeep = {
      enable = true;
      extraEnvironment = {
        PORT         = toString port;
        NEXTAUTH_URL = "https://keep.ironshark.org";
        DISABLE_NEW_RELEASE_CHECK = "true";
        # tagging and summaries from the local model (OpenAI-compatible)
        OPENAI_BASE_URL          = "http://127.0.0.1:8011/v1";
        OPENAI_API_KEY           = "local";
        INFERENCE_TEXT_MODEL     = "chat";
        INFERENCE_CONTEXT_LENGTH = "8192";
        INFERENCE_JOB_TIMEOUT_SEC = "300";   # room for the model to wake up
        # keep pages, not just links
        CRAWLER_FULL_PAGE_ARCHIVE    = "true";
        CRAWLER_FULL_PAGE_SCREENSHOT = "true";
        OCR_LANGS = "eng,chi_sim";
      };
    };

    systemd.services.karakeep-init    = onSrv;
    systemd.services.karakeep-workers = onSrv;
    systemd.services.karakeep-web     = onSrv;
    systemd.tmpfiles.rules = [ "d ${data} 0750 karakeep karakeep -" ];

    tn.web.vhosts.keep = { inherit port; maxBody = "100m"; };
  };
}
