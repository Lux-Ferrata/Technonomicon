{ inputs, ... }: {
  # Report emails with charts. Grafana (127.0.0.1:3001, anonymous read-only,
  # also https://metrics.<domain> on the tailnet) holds the "Akmon report"
  # dashboard (_grafana-report.nix); grafana-image-renderer turns its panels
  # into PNGs; tn-report (_tn-report.py) puts them inline in an HTML mail with
  # tables from VictoriaMetrics, plus a PDF copy on the weekly one.
  #   daily   06:00, from Tn-server-alerts' digest (always sent: no mail means
  #           the box is down)
  #   weekly  Wednesday's CI email (ci/nightly.sh calls `tn-report weekly`)
  # Nobody is expected to open Grafana; it exists to draw the charts.
  flake.nixosModules.Tn-server-reports = { config, lib, pkgs, ... }:
  let
    port      = 3001;
    renderer  = "127.0.0.1:8089";
    stateDir  = "/var/lib/grafana";
    dashboard = import ./_grafana-report.nix {};
    dashboards = pkgs.linkFarm "tn-grafana-dashboards" [
      { name = "akmon-report.json"; path = pkgs.writeText "akmon-report.json" (builtins.toJSON dashboard); }
    ];

    tn-report = pkgs.writers.writePython3Bin "tn-report" {
      libraries   = [ pkgs.python3Packages.weasyprint ];
      flakeIgnore = [ "E501" "W503" ];
    } (builtins.readFile ./_tn-report.py);
  in {
    environment.systemPackages = [ tn-report ];
    tn.alerts.reportCommand = "${tn-report}/bin/tn-report";

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = port;
          domain    = "metrics.${config.tn.web.domain}";
          root_url  = "https://metrics.${config.tn.web.domain}/";
        };
        # minted on first start (tn-grafana-secrets below), never in the store
        security.secret_key = "$__file{${stateDir}/secret_key}";
        # shared with the renderer (Grafana refuses the default token)
        rendering.renderer_token = "$__file{${stateDir}/renderer_token}";
        "auth.anonymous" = { enabled = true; org_role = "Viewer"; };
        auth.disable_login_form = false;
        users.allow_sign_up = false;
        analytics = { reporting_enabled = false; check_for_updates = false; check_for_plugin_updates = false; };
        news.news_feed_enabled = false;
      };
      provision = {
        enable = true;
        datasources.settings.datasources = [ {
          name = "VictoriaMetrics"; uid = "vm"; type = "prometheus";
          url = "http://127.0.0.1:8428"; isDefault = true; editable = false;
        } ];
        dashboards.settings.providers = [ {
          name = "tn"; type = "file"; disableDeletion = true;
          options.path = dashboards;
        } ];
      };
    };
    # Grafana's secret key and the Grafana<->renderer token, made once
    systemd.services.tn-grafana-secrets = {
      description = "Create Grafana's secret key and renderer token";
      before   = [ "grafana.service" "grafana-image-renderer.service" ];
      requiredBy = [ "grafana.service" "grafana-image-renderer.service" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        set -eu
        umask 077
        mkdir -p ${stateDir}
        rand() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
        [ -s ${stateDir}/secret_key ] || rand > ${stateDir}/secret_key
        if [ ! -s ${stateDir}/renderer_token ]; then
          rand > ${stateDir}/renderer_token
        fi
        echo "AUTH_TOKEN=$(cat ${stateDir}/renderer_token)" > ${stateDir}/renderer.env
        chown grafana:grafana ${stateDir} ${stateDir}/secret_key ${stateDir}/renderer_token
        chmod 0700 ${stateDir}
      '';
    };
    # read by systemd (root) before the renderer's DynamicUser exists
    systemd.services.grafana-image-renderer.serviceConfig.EnvironmentFile = "${stateDir}/renderer.env";

    services.grafana-image-renderer = {
      enable           = true;
      provisionGrafana = true;
      settings.server.addr = renderer;
    };

    tn.web.vhosts.metrics = { inherit port; maxBody = "10m"; };

    environment.persistence."/persist".directories = [
      { directory = stateDir; user = "grafana"; group = "grafana"; mode = "0700"; }
    ];
  };
}
