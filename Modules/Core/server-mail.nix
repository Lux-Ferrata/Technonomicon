{ inputs, ... }: {
  # Outgoing mail for headless hosts: msmtp relays through Gmail (Workspace)
  # with an app password from sops. Failed units, ZFS events and SMART
  # warnings all end up in xin's inbox.
  flake.nixosModules.Tn-server-mail = { config, pkgs, ... }:
  let
    from = "homelab@ironshark.org";      # alias on the xin@ Workspace account
    to   = "xin@ironshark.org";
    host = config.networking.hostName;
  in {

    sops.secrets.smtp-password = {};     # root-only; everything below mails as root

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

    # ---- any failed system service -> email ------------------------------
    systemd.services."notify-failure@" = {
      description = "Email about failed unit %i";
      serviceConfig.Type = "oneshot";
      scriptArgs = "%i";
      path = [ config.systemd.package ];
      script = ''
        unit="$1"
        {
          echo "To: ${to}"
          echo "From: ${host} <${from}>"
          echo "Subject: [${host}] $unit failed"
          echo
          systemctl status --full --no-pager "$unit" || true
          echo
          journalctl -u "$unit" -n 60 --no-pager || true
        } 2>&1 | /run/wrappers/bin/sendmail -t
      '';
    };

    # top-level drop-in: every service gets OnFailure=notify-failure@...;
    # the unit-specific drop-in clears it again for the notifier itself so a
    # broken mail setup can't loop
    systemd.packages = [
      (pkgs.runCommand "notify-failure-dropins" {} ''
        mkdir -p $out/etc/systemd/system/service.d $out/etc/systemd/system/notify-failure@.service.d
        cat > $out/etc/systemd/system/service.d/90-notify-failure.conf <<EOF
        [Unit]
        OnFailure=notify-failure@%n.service
        EOF
        cat > $out/etc/systemd/system/notify-failure@.service.d/90-no-loop.conf <<EOF
        [Unit]
        OnFailure=
        EOF
      '')
    ];

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
