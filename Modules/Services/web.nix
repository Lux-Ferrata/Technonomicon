{ inputs, ... }: {
  # Akmon's front door: nginx on the tailnet, one wildcard cert for
  # *.ironshark.org (ACME DNS-01 through Cloudflare), and the shared Postgres.
  # The service names are public A records pointing at Akmon's tailnet IP,
  # so they only work from inside the tailnet. Forgejo keeps its MagicDNS
  # name, with a cert from `tailscale cert` (nginx and `tailscale serve`
  # can't share :443).
  #
  # A service module only declares its name and port:
  #   tn.web.vhosts.docs = { port = 28981; };   ->  https://docs.ironshark.org
  # and its DNS record is created on the next deploy (cloudflare-dns-sync).
  flake.nixosModules.Tn-server-web = { config, lib, pkgs, ... }:
  let
    domain   = "ironshark.org";
    tsName   = "akmon.tail607809.ts.net";
    tsCerts  = "/var/lib/tailscale-cert";
    tailnetIp = "100.122.244.58";   # Akmon; stable while /var/lib/tailscale persists
    tailscale = lib.getExe config.services.tailscale.package;
    pg       = config.services.postgresql;
  in {
    options.tn.web.vhosts = lib.mkOption {
      default = {};
      description = "Services behind nginx at <name>.${domain}.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          port    = lib.mkOption { type = lib.types.port; };
          maxBody = lib.mkOption { type = lib.types.str; default = "100m"; };
          extraConfig = lib.mkOption { type = lib.types.lines; default = ""; };
        };
      });
    };

    config = {
      # ── Certificates ────────────────────────────────────────────────────
      # bare token (Cloudflare: Zone.DNS edit on ironshark.org only)
      sops.secrets.dns-api-token = {};

      security.acme = {
        acceptTerms    = true;
        defaults.email = "xin@ironshark.org";
        certs.${domain} = {
          extraDomainNames = [ "*.${domain}" ];
          dnsProvider      = "cloudflare";
          credentialFiles.CLOUDFLARE_DNS_API_TOKEN_FILE = config.sops.secrets.dns-api-token.path;
          # check the TXT record against public DNS, not the tailnet resolver
          dnsResolver      = "1.1.1.1:53";
          group            = "nginx";
          reloadServices   = [ "nginx" ];
        };
      };

      # MagicDNS name's cert, renewed weekly (Tailscale certs last 90 days)
      systemd.services.tailscale-cert = {
        description = "Fetch the TLS cert for ${tsName}";
        after    = [ "tailscaled.service" "tailscaled-autoconnect.service" ];
        wants    = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type       = "oneshot";
          Restart    = "on-failure";
          RestartSec = 30;
        };
        script = ''
          install -d -m 0750 -g nginx ${tsCerts}
          ${tailscale} cert --cert-file ${tsCerts}/${tsName}.crt \
                            --key-file  ${tsCerts}/${tsName}.key ${tsName}
          chgrp nginx ${tsCerts}/${tsName}.crt ${tsCerts}/${tsName}.key
          chmod 0640  ${tsCerts}/${tsName}.key
          if systemctl is-active -q nginx; then systemctl reload nginx; fi
        '';
      };
      systemd.timers.tailscale-cert = {
        wantedBy    = [ "timers.target" ];
        timerConfig = { OnCalendar = "weekly"; Persistent = true; RandomizedDelaySec = "1h"; };
      };

      # tailscaled keeps serve config in its state: make sure no old
      # `tailscale serve` still claims :443 on the tailnet address
      systemd.services.tailscale-serve-off = {
        description = "Clear tailscale serve (nginx owns :443)";
        after    = [ "tailscaled.service" "tailscaled-autoconnect.service" ];
        wants    = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; Restart = "on-failure"; RestartSec = 15; };
        script = "${tailscale} serve reset";
      };

      # ── DNS: every vhost gets its record ────────────────────────────────
      # Ensures <name>.ironshark.org is an A record -> Akmon's tailnet IP,
      # DNS only, for each tn.web.vhosts name. Creates or corrects exactly
      # those records; never deletes and never touches anything else in the
      # zone (mail, the apex, www are hand-managed).
      systemd.services.cloudflare-dns-sync = let
        names = lib.concatStringsSep " " (lib.attrNames config.tn.web.vhosts);
      in {
        description = "Ensure Cloudflare A records for Akmon's services";
        after    = [ "network-online.target" ];
        wants    = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ names ];   # re-run when a service is added
        path = [ pkgs.curl pkgs.jq ];
        serviceConfig = {
          Type            = "oneshot";
          RemainAfterExit = true;
          Restart         = "on-failure";
          RestartSec      = 60;
          DynamicUser     = true;
          LoadCredential  = "token:${config.sops.secrets.dns-api-token.path}";
        };
        script = ''
          api=https://api.cloudflare.com/client/v4
          auth="Authorization: Bearer $(tr -d '\n' < "$CREDENTIALS_DIRECTORY/token")"
          cf() { curl -sSf -H "$auth" -H 'Content-Type: application/json' "$@"; }
          zone=$(cf "$api/zones?name=${domain}" | jq -er '.result[0].id')
          for n in ${names}; do
            fqdn=$n.${domain}
            rec=$(cf "$api/zones/$zone/dns_records?type=A&name=$fqdn" | jq -c '.result[0] // empty')
            body=$(jq -nc --arg n "$fqdn" --arg ip ${tailnetIp} \
              '{type:"A", name:$n, content:$ip, ttl:1, proxied:false, comment:"managed by Tn-server-web"}')
            if [ -z "$rec" ]; then
              cf -X POST "$api/zones/$zone/dns_records" -d "$body" >/dev/null
              echo "created $fqdn"
            elif [ "$(jq -r '"\(.content) \(.proxied)"' <<<"$rec")" != "${tailnetIp} false" ]; then
              cf -X PATCH "$api/zones/$zone/dns_records/$(jq -r .id <<<"$rec")" -d "$body" >/dev/null
              echo "corrected $fqdn"
            fi
          done
        '';
      };

      # ── nginx ───────────────────────────────────────────────────────────
      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings   = true;
        recommendedGzipSettings  = true;
        recommendedOptimisation  = true;

        virtualHosts = lib.mapAttrs' (name: v: lib.nameValuePair "${name}.${domain}" {
          forceSSL    = true;
          useACMEHost = domain;
          locations."/" = {
            proxyPass       = "http://127.0.0.1:${toString v.port}";
            proxyWebsockets = true;
          };
          extraConfig = ''
            client_max_body_size ${v.maxBody};
            ${v.extraConfig}
          '';
        }) config.tn.web.vhosts // {
          # Forgejo, at the name every remote, script and runner already uses
          ${tsName} = {
            forceSSL           = true;
            sslCertificate     = "${tsCerts}/${tsName}.crt";
            sslCertificateKey  = "${tsCerts}/${tsName}.key";
            locations."/".proxyPass = "http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}";
            extraConfig = "client_max_body_size 1g;";   # LFS, release assets
          };
          # anything else (bare IP, unknown names) gets nothing
          "_" = {
            default   = true;
            rejectSSL = true;
            locations."/".return = "444";
          };
        };
      };
      systemd.services.nginx = {
        wants = [ "tailscale-cert.service" ];
        after = [ "tailscale-cert.service" "tailscale-serve-off.service" ];
      };
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 443 ];

      # ── Shared Postgres (on the fast pool, snapshotted by sanoid) ───────
      services.postgresql = {
        enable  = true;
        package = pkgs.postgresql_17;
        dataDir = "/srv/postgresql/${pg.package.psqlSchema}";
      };
      systemd.services.postgresql = {
        requires = [ "zfs-mount.service" ];
        after    = [ "zfs-mount.service" ];
      };
      # snapshots of a live database are only crash-consistent; dumps are clean
      services.postgresqlBackup = {
        enable      = true;
        backupAll   = true;
        location    = "/srv/backup/postgresql";
        compression = "zstd";
        startAt     = "*-*-* 02:15:00";   # clear of overnight (00:10), weekly (Wed 03:00), upgrade (06:00)
      };
      systemd.tmpfiles.rules = [
        "d /srv/postgresql         0750 postgres postgres -"
        "d /srv/backup             0755 root     root     -"
        "d /srv/backup/postgresql  0700 postgres postgres -"
      ];

      environment.persistence."/persist".directories = [
        "/var/lib/acme"
        tsCerts
      ];
    };
  };
}
