{ inputs, ... }: {
  # Metrics for headless hosts: one year of history in VictoriaMetrics, for
  # Claude to query (`curl -s 127.0.0.1:8428/api/v1/query?query=...`) and for
  # the chart emails. Nobody is expected to look at it directly.
  #
  #   VictoriaMetrics  127.0.0.1:8428, scrapes everything below every 30 s
  #   node             CPU, memory, pressure, temps, disks, net, ARC, OOM kills
  #   systemd          unit states, timers' last trigger
  #   smartctl         disk health
  #   nvidia-gpu       GPU use, VRAM, power, temperature
  #   postgres         the shared Postgres
  #   nginxlog         status codes + latency per vhost (Tn-server-web's stats.log)
  #   blackbox         every tn.web.vhosts name over HTTPS (+ cert expiry),
  #                    IMAP/SMB/ssh over TCP, Forgejo's Actions API
  #   textfile (tn-metrics-collect, below)
  #                    per-unit memory/CPU/restarts (systemd's cgroup
  #                    accounting), last success of each tn.metrics.jobs entry
  #                    (from the journal, so it survives reboots and unit
  #                    unloading), ZFS pools + newest snapshot, curated tag,
  #                    pending reboot
  #
  # The journal (persisted, 1 year) stays the log store: `journalctl` is the
  # query tool, so there is no Loki. Alert rules live in Tn-server-alerts.
  flake.nixosModules.Tn-server-metrics = { config, lib, pkgs, ... }:
  let
    cfg      = config.tn.metrics;
    exp      = config.services.prometheus.exporters;
    textfile = "/var/lib/tn-metrics/textfile";
    local    = name: "127.0.0.1:${toString exp.${name}.port}";

    # unit -> { maxAge seconds, user unit? }
    jobType = lib.types.submodule {
      options = {
        maxAge = lib.mkOption { type = lib.types.int; description = "Alert when the last success is older (seconds)."; };
        user   = lib.mkOption { type = lib.types.bool; default = false; description = "A user unit (journal field USER_UNIT)."; };
      };
    };

    collect = pkgs.writeShellApplication {
      name = "tn-metrics-collect";
      runtimeInputs = with pkgs; [ coreutils gawk gnugrep systemd jq gitMinimal config.boot.zfs.package ];
      text = ''
        out=${textfile}
        mkdir -p "$out"
        # write NAME.prom atomically from stdin
        emit() { cat > "$out/.$1.tmp" && mv "$out/.$1.tmp" "$out/$1.prom"; }

        case "''${1:-fast}" in
        fast)
          # per-unit resources from systemd's own cgroup accounting
          mapfile -t units < <(systemctl list-units --type=service --state=running,failed \
                                 --no-legend --plain | awk '{print $1}')
          [ ''${#units[@]} -gt 0 ] || exit 0
          systemctl show "''${units[@]}" -p Id,MemoryCurrent,CPUUsageNSec,NRestarts |
            awk -F= '
              BEGIN {
                print "# TYPE tn_unit_memory_bytes gauge"
                print "# TYPE tn_unit_cpu_seconds_total counter"
                print "# TYPE tn_unit_restarts_total counter"
              }
              $1 == "Id"            { u = $2 }
              $1 == "MemoryCurrent" && $2 ~ /^[0-9]+$/ && $2 < 1e18 { printf "tn_unit_memory_bytes{unit=\"%s\"} %s\n", u, $2 }
              $1 == "CPUUsageNSec"  && $2 ~ /^[0-9]+$/ && $2 < 1e18 { printf "tn_unit_cpu_seconds_total{unit=\"%s\"} %.3f\n", u, $2/1e9 }
              $1 == "NRestarts"     && $2 ~ /^[0-9]+$/ { printf "tn_unit_restarts_total{unit=\"%s\"} %s\n", u, $2 }
            ' | emit units
          ;;
        slow)
          # last successful run of each job: oneshots log "Finished ..." with
          # JOB_TYPE=start JOB_RESULT=done when they exit 0
          {
            echo "# TYPE tn_job_last_success_timestamp_seconds gauge"
            echo "# TYPE tn_job_max_age_seconds gauge"
            while read -r unit field maxage; do
              us=$(journalctl "$field=$unit" JOB_TYPE=start JOB_RESULT=done -n1 -o json --no-pager \
                     | jq -r '.__REALTIME_TIMESTAMP // empty')
              [ -n "$us" ] && echo "tn_job_last_success_timestamp_seconds{unit=\"$unit\"} $((us / 1000000))"
              echo "tn_job_max_age_seconds{unit=\"$unit\"} $maxage"
            done <<'JOBS'
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (u: j:
          "${u}.service ${if j.user then "USER_UNIT" else "UNIT"} ${toString j.maxAge}") cfg.jobs)}
        JOBS
          } | emit jobs

          # ZFS pools: capacity, fragmentation, health, newest snapshot
          {
            echo "# TYPE tn_zpool_size_bytes gauge"
            zpool list -Hp -o name,size,alloc,free,frag,health | while read -r p size alloc free frag health; do
              echo "tn_zpool_size_bytes{pool=\"$p\"} $size"
              echo "tn_zpool_alloc_bytes{pool=\"$p\"} $alloc"
              echo "tn_zpool_free_bytes{pool=\"$p\"} $free"
              [ "$frag" != "-" ] && echo "tn_zpool_fragmentation_percent{pool=\"$p\"} ''${frag%\%}"
              echo "tn_zpool_healthy{pool=\"$p\",health=\"$health\"} $([ "$health" = ONLINE ] && echo 1 || echo 0)"
              snap=$(zfs list -Hp -t snapshot -o creation -s creation -r "$p" 2>/dev/null | tail -n1) || true
              [ -n "$snap" ] && echo "tn_zfs_newest_snapshot_timestamp_seconds{pool=\"$p\"} $snap"
            done
          } | emit zfs

          {
            # the weekly CI job's last cutoff (Tn-forgejo); absent elsewhere
            repo=${lib.optionalString config.services.forgejo.enable "${config.services.forgejo.repositoryRoot}/xin/technonomicon.git"}
            if [ -n "$repo" ] && [ -d "$repo" ]; then
              t=$(git -c safe.directory='*' -C "$repo" for-each-ref --sort=-creatordate --count=1 \
                    --format='%(creatordate:unix)' refs/tags/curated/)
              [ -n "$t" ] && echo "tn_weekly_last_curated_timestamp_seconds $t"
            fi
            # kernel/initrd/modules changed since boot -> a reboot is pending
            pending=0
            for f in kernel initrd kernel-modules; do
              [ "$(readlink -f /run/booted-system/$f)" = "$(readlink -f /run/current-system/$f)" ] || pending=1
            done
            echo "tn_reboot_pending $pending"
            echo "tn_system_switch_timestamp_seconds $(stat -c %Y /nix/var/nix/profiles/system)"
          } | emit system
          ;;
        esac
      '';
    };
  in {
    options.tn.metrics.jobs = lib.mkOption {
      type        = lib.types.attrsOf jobType;
      default     = {};
      description = "Scheduled units whose last success is tracked (and alerted on when stale).";
      example     = { postgresqlBackup.maxAge = 26 * 3600; };
    };

    config = {
      tn.metrics.jobs = {
        postgresqlBackup = lib.mkIf config.services.postgresqlBackup.enable { maxAge = 26 * 3600; };
        sanoid           = lib.mkIf config.services.sanoid.enable           { maxAge = 3 * 3600; };
        nixos-upgrade    = lib.mkIf config.system.autoUpgrade.enable        { maxAge = 26 * 3600; };
      };

      services.victoriametrics = {
        enable          = true;
        listenAddress   = "127.0.0.1:8428";
        retentionPeriod = "1y";
        prometheusConfig = {
          global.scrape_interval = "30s";
          scrape_configs = [
            { job_name = "victoriametrics"; static_configs = [ { targets = [ "127.0.0.1:8428" ]; } ]; }
            { job_name = "node";       static_configs = [ { targets = [ (local "node") ]; } ]; }
            { job_name = "systemd";    static_configs = [ { targets = [ (local "systemd") ]; } ]; }
            { job_name = "smartctl";   static_configs = [ { targets = [ (local "smartctl") ]; } ]; scrape_interval = "5m"; }
            { job_name = "nvidia-gpu"; static_configs = [ { targets = [ (local "nvidia-gpu") ]; } ]; }
            { job_name = "postgres";   static_configs = [ { targets = [ (local "postgres") ]; } ]; }
            { job_name = "nginxlog";   static_configs = [ { targets = [ (local "nginxlog") ]; } ]; }
            # blackbox: target -> ?target=..., instance label keeps the target
            {
              job_name = "probe-https";
              metrics_path = "/probe";
              params.module = [ "https" ];
              static_configs = [ {
                targets = map (n: "https://${n}.${config.tn.web.domain}/") (lib.attrNames config.tn.web.vhosts);
              } ];
              relabel_configs = [
                { source_labels = [ "__address__" ]; target_label = "__param_target"; }
                { source_labels = [ "__param_target" ]; target_label = "instance"; }
                { target_label = "__address__"; replacement = local "blackbox"; }
              ];
            }
            {
              job_name = "probe-tcp";
              metrics_path = "/probe";
              params.module = [ "tcp" ];
              static_configs = [ { targets = [
                "${config.tn.web.tailnetIp}:22"
                "${config.tn.web.tailnetIp}:445"
              ]; } ];
              relabel_configs = [
                { source_labels = [ "__address__" ]; target_label = "__param_target"; }
                { source_labels = [ "__param_target" ]; target_label = "instance"; }
                { target_label = "__address__"; replacement = local "blackbox"; }
              ];
            }
            {
              job_name = "probe-tls";
              metrics_path = "/probe";
              params.module = [ "tls" ];
              static_configs = [ { targets = [ "mail.${config.tn.web.domain}:993" ]; } ];
              relabel_configs = [
                { source_labels = [ "__address__" ]; target_label = "__param_target"; }
                { source_labels = [ "__param_target" ]; target_label = "instance"; }
                { target_label = "__address__"; replacement = local "blackbox"; }
              ];
            }
            {
              job_name = "probe-forgejo-actions";
              metrics_path = "/probe";
              params.module = [ "connect_ping" ];
              static_configs = [ { targets = [ "http://127.0.0.1:3000/api/actions/ping.v1.PingService/Ping" ]; } ];
              relabel_configs = [
                { source_labels = [ "__address__" ]; target_label = "__param_target"; }
                { source_labels = [ "__param_target" ]; target_label = "instance"; }
                { target_label = "__address__"; replacement = local "blackbox"; }
              ];
            }
          ];
        };
      };

      services.prometheus.exporters = {
        node = {
          enable        = true;
          listenAddress = "127.0.0.1";
          enabledCollectors = [ "processes" ];
          extraFlags    = [ "--collector.textfile.directory=${textfile}" ];
        };
        systemd  = { enable = true; listenAddress = "127.0.0.1"; };
        smartctl = { enable = true; listenAddress = "127.0.0.1"; };
        nvidia-gpu = lib.mkIf config.hardware.nvidia.enabled {
          enable = true; listenAddress = "127.0.0.1";
        };
        postgres = lib.mkIf config.services.postgresql.enable {
          enable = true; listenAddress = "127.0.0.1"; runAsLocalSuperUser = true;
        };
        nginxlog = lib.mkIf config.services.nginx.enable {
          enable        = true;
          listenAddress = "127.0.0.1";
          settings.namespaces = [ {
            name   = "nginx";
            format = "$host $status $request_time \"$request_method\" $body_bytes_sent";
            source.files = [ "/var/log/nginx/stats.log" ];
            relabel_configs = [ { target_label = "vhost"; from = "host"; } ];
            histogram_buckets = [ 0.01 0.05 0.1 0.25 0.5 1 2.5 5 10 ];
          } ];
        };
        blackbox = {
          enable        = true;
          listenAddress = "127.0.0.1";
          configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
            modules = {
              # "the service answers": anything but a 5xx/timeout (login
              # pages redirect, WebDAV/CalDAV ask for auth)
              https = {
                prober = "http";
                timeout = "10s";
                http = {
                  valid_status_codes = [ 200 204 301 302 303 307 308 401 403 404 405 ];
                  follow_redirects = false;
                  fail_if_not_ssl = true;
                  preferred_ip_protocol = "ip4";
                };
              };
              tcp = { prober = "tcp"; timeout = "5s"; tcp.preferred_ip_protocol = "ip4"; };
              tls = { prober = "tcp"; timeout = "5s"; tcp = { tls = true; preferred_ip_protocol = "ip4"; }; };
              # the Actions API the runner talks to (connect-rpc ping)
              connect_ping = {
                prober = "http";
                timeout = "5s";
                http = {
                  method = "POST";
                  headers."Content-Type" = "application/json";
                  body = "{}";
                  valid_status_codes = [ 200 ];
                };
              };
            };
          });
        };
      };

      # stats.log is nginx's (0750 nginx:nginx)
      systemd.services.prometheus-nginxlog-exporter = lib.mkIf config.services.nginx.enable {
        serviceConfig.SupplementaryGroups = [ "nginx" ];
        after = [ "nginx.service" ];
      };

      # ── textfile collector ──────────────────────────────────────────────
      systemd.tmpfiles.rules = [ "d ${textfile} 0755 root root -" ];
      systemd.services.tn-metrics-fast = {
        description = "Per-unit resource metrics";
        serviceConfig = { Type = "oneshot"; ExecStart = "${collect}/bin/tn-metrics-collect fast"; };
      };
      systemd.timers.tn-metrics-fast = {
        wantedBy = [ "timers.target" ];
        timerConfig = { OnCalendar = "minutely"; AccuracySec = "5s"; };
      };
      systemd.services.tn-metrics-slow = {
        description = "Job freshness, ZFS and system metrics";
        serviceConfig = { Type = "oneshot"; ExecStart = "${collect}/bin/tn-metrics-collect slow"; };
      };
      systemd.timers.tn-metrics-slow = {
        wantedBy = [ "timers.target" ];
        timerConfig = { OnCalendar = "*:0/5"; AccuracySec = "10s"; };
      };
      environment.systemPackages = [ collect ];

      # ── journal: the log store Claude queries ──────────────────────────
      services.journald.settings.Journal = {
        SystemMaxUse    = "8G";
        MaxRetentionSec = "1year";
      };
    };
  };
}
