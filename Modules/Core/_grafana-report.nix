# The "Akmon report" Grafana dashboard: the panels tn-report renders into the
# daily and weekly emails (one PNG per panel, light theme). Everything else
# in the emails (status, uptime %, pools, jobs, top services) is an HTML table
# tn-report builds straight from VictoriaMetrics.
#
# Chart rules (dataviz skill): change-over-time panels only; fixed series
# colours in categorical slot order (blue, orange, aqua, yellow), never by
# rank; 2 px lines, no points, one y-axis per panel; status colours only for
# up/down, always with a text label; a legend whenever there are 2+ series.
{ timezone ? "America/Phoenix" }:
let
  slot = [ "#2a78d6" "#eb6834" "#1baf7a" "#eda100" ];   # reference palette, light
  good = "#0ca30c";
  critical = "#d03b3b";

  ds = { type = "prometheus"; uid = "vm"; };

  target = ref: expr: legend: { refId = ref; datasource = ds; inherit expr; legendFormat = legend; range = true; };

  # series name -> fixed colour
  colourOverrides = names: builtins.genList (i: {
    matcher = { id = "byName"; options = builtins.elemAt names i; };
    properties = [ { id = "color"; value = { mode = "fixed"; fixedColor = builtins.elemAt slot i; }; } ];
  }) (builtins.length names);

  timeseries = { id, title, unit, targets, names, stack ? false, min ? 0, max ? null, decimals ? null }: {
    inherit id title targets;
    type = "timeseries";
    datasource = ds;
    gridPos = { x = 0; y = id * 8; w = 24; h = 8; };
    options = {
      legend = { showLegend = builtins.length names > 1; displayMode = "list"; placement = "bottom"; };
      tooltip.mode = "multi";
    };
    fieldConfig = {
      defaults = {
        inherit unit min decimals;
        color.mode = "fixed";
        custom = {
          drawStyle = "line";
          lineWidth = 2;
          fillOpacity = if stack then 35 else 0;
          gradientMode = "none";
          showPoints = "never";
          spanNulls = 120000;          # bridge single missed scrapes, not outages
          stacking = { mode = if stack then "normal" else "none"; group = "A"; };
          axisBorderShow = false;
        };
      } // (if max == null then {} else { inherit max; });
      overrides = colourOverrides names;
    };
  };
in {
  uid = "akmon-report";
  title = "Akmon report";
  inherit timezone;
  editable = false;
  schemaVersion = 39;
  time = { from = "now-24h"; to = "now"; };
  panels = [
    (timeseries {
      id = 1; title = "CPU and GPU busy"; unit = "percent"; max = 100;
      names = [ "CPU" "GPU" ];
      targets = [
        (target "A" ''100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])))'' "CPU")
        (target "B" ''100 * avg(nvidia_smi_utilization_gpu_ratio)'' "GPU")
      ];
    })
    (timeseries {
      id = 2; title = "Memory (RAM)"; unit = "bytes"; stack = true;
      names = [ "Apps" "ZFS cache (ARC)" ];
      targets = [
        (target "A" ''node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes - node_zfs_arc_size'' "Apps")
        (target "B" ''node_zfs_arc_size'' "ZFS cache (ARC)")
      ];
    })
    {
      id = 3;
      title = "Service availability";
      type = "state-timeline";
      datasource = ds;
      gridPos = { x = 0; y = 24; w = 24; h = 12; };
      targets = [
        (target "A" ''label_replace(probe_success{job="probe-https"}, "svc", "$1", "instance", "https://([^.]+)\\..*")'' "{{svc}}")
        (target "B" ''probe_success{job="probe-tcp", instance=~".*:22"}'' "ssh")
        (target "C" ''probe_success{job="probe-tcp", instance=~".*:445"}'' "smb")
        (target "D" ''probe_success{job="probe-tls"}'' "imap")
      ];
      options = {
        showValue = "never";
        mergeValues = true;
        rowHeight = 0.8;
        alignValue = "left";
        legend = { showLegend = true; displayMode = "list"; placement = "bottom"; };
      };
      fieldConfig = {
        defaults = {
          color.mode = "fixed";
          mappings = [ {
            type = "value";
            options = {
              "1" = { text = "up"; color = good; index = 0; };
              "0" = { text = "down"; color = critical; index = 1; };
            };
          } ];
        };
        overrides = [];
      };
    }
    (timeseries {
      id = 4; title = "Temperatures"; unit = "celsius"; min = 20;
      names = [ "CPU" "GPU" "NVMe (hottest)" ];
      targets = [
        (target "A" ''max(node_hwmon_temp_celsius{chip=~".*coretemp.*"})'' "CPU")
        (target "B" ''max(nvidia_smi_temperature_gpu)'' "GPU")
        (target "C" ''max(node_hwmon_temp_celsius{chip=~".*nvme.*"})'' "NVMe (hottest)")
      ];
    })
    (timeseries {
      id = 5; title = "Pool usage"; unit = "bytes";
      names = [ "rpool" "fast" ];
      targets = [
        (target "A" ''tn_zpool_alloc_bytes{pool="rpool"}'' "rpool")
        (target "B" ''tn_zpool_alloc_bytes{pool="fast"}'' "fast")
      ];
    })
    (timeseries {
      id = 6; title = "Web errors (HTTP 5xx per minute, all sites)"; unit = "short"; decimals = 1;
      names = [ "5xx/min" ];
      targets = [
        (target "A" ''60 * sum(rate(nginx_http_response_count_total{status=~"5.."}[$__rate_interval])) or vector(0)'' "5xx/min")
      ];
    })
    (timeseries {
      id = 7; title = "GPU memory (VRAM) in use"; unit = "bytes";
      names = [ "VRAM" ];
      targets = [
        (target "A" ''sum(nvidia_smi_memory_used_bytes)'' "VRAM")
      ];
    })
  ];
}
