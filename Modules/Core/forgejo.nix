{ inputs, ... }: {
  # Forgejo: primary git host + Actions CI, tailnet-only.
  #   web:  https://<host>.<tailnet>.ts.net  (tailscale serve -> 127.0.0.1:3000)
  #   ssh:  forgejo@<host>:<owner>/<repo>.git (through the system sshd)
  # Data lives on the fast pool (/srv/forgejo); the admin account is created
  # from sops on first start.
  flake.nixosModules.Tn-forgejo = { config, lib, pkgs, ... }:
  let
    cfg     = config.services.forgejo;
    tsName  = "akmon.tail607809.ts.net";
    admin   = "xin";
  in {

    sops.secrets.forgejo-admin-password = { owner = cfg.user; };

    services.forgejo = {
      enable   = true;
      stateDir = "/srv/forgejo";
      database.type = "sqlite3";
      lfs.enable    = true;

      settings = {
        DEFAULT.APP_NAME = "Forgejo on Akmon";
        server = {
          DOMAIN     = tsName;
          ROOT_URL   = "https://${tsName}/";
          HTTP_ADDR  = "127.0.0.1";
          HTTP_PORT  = 3000;
          SSH_DOMAIN = config.networking.hostName;
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
      if ! "$forgejo" admin user list --admin | awk 'NR>1 {print $2}' | grep -qx '${admin}'; then
        "$forgejo" admin user create --admin \
          --username '${admin}' --email 'xin@ironshark.org' \
          --password "$(tr -d '\n' < ${config.sops.secrets.forgejo-admin-password.path})" \
          --must-change-password=false
      fi
    '';

    # HTTPS on the tailnet name; tailscaled persists the serve config, this
    # just (re)asserts it on every boot
    systemd.services.tailscale-serve-forgejo = {
      description = "Expose Forgejo on the tailnet over HTTPS";
      after       = [ "tailscaled.service" "tailscaled-autoconnect.service" "forgejo.service" ];
      wants       = [ "tailscaled.service" ];
      wantedBy    = [ "multi-user.target" ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        Restart         = "on-failure";
        RestartSec      = 15;
      };
      script = "${lib.getExe config.services.tailscale.package} serve --bg --https=443 http://127.0.0.1:3000";
    };
  };
}
