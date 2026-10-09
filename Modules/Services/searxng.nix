{ inputs, ... }: {
  # SearXNG at https://search.ironshark.org: one query fanned out to ~90
  # engines (general web, reference, science, dev docs), merged and ranked.
  # Brave's default search engine (Tn-web-browsers), and `lagent search`
  # (agents/lagent.sh) reads its JSON API for the overnight research agents.
  # Tailnet-only and single-user, so no rate limiter (and no valkey).
  flake.nixosModules.Tn-searxng = { config, pkgs, ... }:
  let
    port = 8890;
    on = name: { inherit name; disabled = false; inactive = false; };
  in {
    sops.secrets.searxng-secret = {};
    sops.templates."searxng.env".content = ''
      SEARXNG_SECRET=${config.sops.placeholder.searxng-secret}
    '';

    services.searx = {
      enable = true;
      package = pkgs.searxng;
      environmentFile = config.sops.templates."searxng.env".path;
      settings = {
        use_default_settings = true;
        server = {
          bind_address = "127.0.0.1";
          inherit port;
          base_url     = "https://search.ironshark.org/";
          secret_key   = "$SEARXNG_SECRET";
          limiter      = false;
          image_proxy  = false;
        };
        search = {
          formats      = [ "html" "json" ];   # json: lagent search
          autocomplete = "";
        };
        ui.default_theme = "simple";
        # on top of SearXNG's ~80 default engines, the ones it ships off
        engines = map on [
          "google" "bing" "qwant" "yahoo" "startpage" "mojeek"
          "crossref" "openalex" "nixos wiki"
        ];
      };
    };

    tn.web.vhosts.search = { inherit port; maxBody = "1m"; };
  };
}
