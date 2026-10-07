{ inputs, ... }: {
  # Outgoing mail for headless hosts: msmtp relays through Gmail (Workspace)
  # with an app password from sops. ZFS events and SMART warnings mail
  # directly; failed units and journal errors go through Tn-server-alerts.
  flake.nixosModules.Tn-server-mail = { config, pkgs, ... }:
  let
    from = "homelab@ironshark.org";      # alias on the xin@ Workspace account
    to   = "xin@ironshark.org";
    host = config.networking.hostName;
  in {

    # root + members of mail-senders (e.g. the CI runner) can send
    users.groups.mail-senders = {};
    sops.secrets.smtp-password = { group = "mail-senders"; mode = "0440"; };

    programs.msmtp = {
      enable       = true;
      setSendmail  = true;               # /run/wrappers/bin/sendmail
      defaults = {
        aliases = "/etc/aliases";
        tls     = true;
        port    = 587;
      };
      accounts.default = {
        host            = "smtp.gmail.com";
        tls_starttls    = true;
        auth            = true;
        user            = to;            # the app password belongs to this account
        from            = from;
        passwordeval    = "cat ${config.sops.secrets.smtp-password.path}";
      };
    };

    environment.etc."aliases".text = ''
      root: ${to}
      default: ${to}
    '';

    # ---- ZFS: pool faults, resilvers, scrub results -----------------------
    services.zfs.zed = {
      enableMail = false;                # use msmtp below instead of mailutils
      settings = {
        ZED_EMAIL_ADDR           = [ to ];
        ZED_EMAIL_PROG           = "/run/wrappers/bin/sendmail";
        ZED_EMAIL_OPTS           = "@ADDRESS@";
        ZED_NOTIFY_INTERVAL_SECS = 3600;
        ZED_NOTIFY_VERBOSE       = true; # also mail "scrub finished OK"
        ZED_SCRUB_AFTER_RESILVER = true;
      };
    };

    # ---- SMART: dying disks ------------------------------------------------
    services.smartd = {
      enable = true;
      notifications.mail = {
        enable    = true;
        sender    = from;
        recipient = to;
      };
    };
  };
}
