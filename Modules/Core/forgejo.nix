{ inputs, ... }: {
  # Forgejo: primary git host + Actions CI, tailnet-only.
  #   web:  https://git.ironshark.org  (nginx -> 127.0.0.1:3000, Tn-server-web;
  #         the old https://akmon.tail607809.ts.net still works)
  #   ssh:  forgejo@<host>:<owner>/<repo>.git (through the system sshd)
  # Data lives on the fast pool (/srv/forgejo); the admin account is created
  # from sops on first start.
  flake.nixosModules.Tn-forgejo = { config, lib, pkgs, ... }:
  let
    cfg     = config.services.forgejo;
    name    = "git.ironshark.org";
    admin   = "xin";
  in {

    sops.secrets.forgejo-admin-password = { owner = cfg.user; };

    tn.web.vhosts.git = { port = cfg.settings.server.HTTP_PORT; maxBody = "1g"; };   # LFS, release assets

    services.forgejo = {
      enable   = true;
      stateDir = "/srv/forgejo";
      database.type = "sqlite3";
      lfs.enable    = true;

      settings = {
        DEFAULT.APP_NAME = "Forgejo on Akmon";
        server = {
          DOMAIN     = name;
          ROOT_URL   = "https://${name}/";
          HTTP_ADDR  = "127.0.0.1";
          HTTP_PORT  = 3000;
          SSH_DOMAIN = lib.toLower config.networking.hostName;
        };
        service.DISABLE_REGISTRATION = true;
        session.COOKIE_SECURE         = true;
        actions = {
          ENABLED             = true;
          DEFAULT_ACTIONS_URL = "https://code.forgejo.org";
        };
        mailer = {
          ENABLED   = true;
          PROTOCOL  = "smtp+starttls";
          SMTP_ADDR = "smtp.gmail.com";
          SMTP_PORT = 587;
          USER      = "xin@ironshark.org";
          FROM      = "Forgejo <homelab@ironshark.org>";
        };
      };
      secrets.mailer.PASSWD = config.sops.secrets.smtp-password.path;
    };

    # idempotent: only creates the admin if it doesn't exist yet
    systemd.services.forgejo.preStart = lib.mkAfter ''
      forgejo="${lib.getExe cfg.package}"
      # columns: ID Username Email ...; only coreutils/grep/sed are on PATH here
      if ! "$forgejo" admin user list --admin | grep -Eq '^[0-9]+[[:space:]]+${admin}[[:space:]]'; then
        "$forgejo" admin user create --admin \
          --username '${admin}' --email 'xin@ironshark.org' \
          --password "$(tr -d '\n' < ${config.sops.secrets.forgejo-admin-password.path})" \
          --must-change-password=false
      fi
    '';

    # ---- Actions runner ---------------------------------------------------
    # Forgejo mints a registration token on every start; the runner only uses
    # it the first time (afterwards it has its own .runner credentials, which
    # live under /var/lib/private -- persisted in _impermanence.nix).
    systemd.services.forgejo.postStart = lib.mkAfter ''
      tok=$("${lib.getExe cfg.package}" actions generate-runner-token)
      install -m 0600 /dev/null ${cfg.stateDir}/runner-token.env
      echo "TOKEN=$tok" > ${cfg.stateDir}/runner-token.env

      # Tn-server-alerts files issues with this (issue scope only; root reads
      # it, Claude's review never does). Minted once; delete the file to renew.
      tokfile=${cfg.stateDir}/akmon-health-token
      if [ ! -s "$tokfile" ]; then
        ( umask 077
          "${lib.getExe cfg.package}" admin user generate-access-token --username '${admin}' \
            --token-name "akmon-health-$(date +%s)" --scopes write:issue,read:repository --raw > "$tokfile.tmp" \
          && mv "$tokfile.tmp" "$tokfile" ) || echo "akmon-health token: generation failed (issues stay off)"
      fi
    '';

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.akmon = {
        enable    = true;
        name      = config.networking.hostName;
        # same host: talk to Forgejo directly, so the runner doesn't race
        # tailscaled/MagicDNS at boot (jobs still see ROOT_URL as server_url)
        url       = "http://127.0.0.1:${toString cfg.settings.server.HTTP_PORT}";
        tokenFile = "${cfg.stateDir}/runner-token.env";
        # jobs run straight on the host (no containers): `runs-on: nixos`
        labels    = [ "nixos:host" ];
        hostPackages = with pkgs; [
          bash coreutils findutils gnugrep gnused gawk diffutils
          gitMinimal openssh curl jq
          nix
          nodejs            # JS actions such as actions/checkout
          claude-code       # nightly job: fixes, grouping, summary (ci/nightly.sh)
        ];
        settings.runner = {
          capacity = 2;
          timeout  = "12h"; # first weekly run builds every host from scratch
        };
      };
    };

    # secrets jobs may read (DynamicUser can still join static groups)
    users.groups.ci-secrets = {};
    sops.secrets.claude-oauth-token = { group = "ci-secrets"; mode = "0440"; };

    systemd.services."gitea-runner-akmon" = {
      after = [ "forgejo.service" ];
      wants = [ "forgejo.service" ];
      serviceConfig.SupplementaryGroups = [ "ci-secrets" "mail-senders" ];
    };
  };
}
