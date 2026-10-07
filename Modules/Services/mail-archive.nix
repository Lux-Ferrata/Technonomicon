{ inputs, ... }: {
  # Permanent mail archive on Akmon. Every 15 minutes mbsync pulls each
  # account into /srv/mail/<account>/ (Maildir, snapshotted) and never
  # deletes anything, so mail survives being deleted at the provider.
  # Dovecot serves it read-only over IMAPS at mail.ironshark.org:993
  # (tailnet only, user xin) with full-text search, attachments included
  # (Tika, shared with Paperless) -- Thunderbird's "Archive" account.
  #
  # Adding an account: one entry in tn.mailArchive.accounts plus its
  # password in sops. Gmail/Workspace takes an app password; providers
  # that only allow OAuth2 (most school Microsoft 365) need an OAuth token
  # helper first -- see TODO.md.
  flake.nixosModules.Tn-mail-archive = { config, lib, pkgs, ... }:
  let
    cfg   = config.tn.mailArchive;
    root  = "/srv/mail";
    index = "/srv/mail-index";
    user  = "mailarchive";
    creds = "/run/credentials/mail-archive-sync.service";
    acme  = config.security.acme.certs."ironshark.org".directory;

    mbsyncrc = pkgs.writeText "mbsyncrc" (lib.concatStrings (lib.mapAttrsToList (name: a: ''
      IMAPAccount ${name}
      Host ${a.host}
      User ${a.user}
      PassCmd "cat ${creds}/${name}"
      TLSType IMAPS

      IMAPStore ${name}-remote
      Account ${name}

      MaildirStore ${name}-local
      Path ${root}/${name}/
      Inbox ${root}/${name}/INBOX
      SubFolders Verbatim

      Channel ${name}
      Far :${name}-remote:
      Near :${name}-local:
      Patterns ${lib.concatMapStringsSep " " (p: ''"${p}"'') a.patterns}
      Create Near
      # new mail and flag changes only: nothing gone at the far end is
      # ever removed here
      Sync PullNew PullFlags
      Expunge None
      CopyArrivalDate yes
      SyncState *

    '') cfg.accounts));
  in {
    options.tn.mailArchive.accounts = lib.mkOption {
      default = {};
      description = "IMAP accounts mirrored into the archive.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          host     = lib.mkOption { type = lib.types.str; };
          user     = lib.mkOption { type = lib.types.str; };
          passwordSecret = lib.mkOption { type = lib.types.str; description = "sops secret holding the password."; };
          patterns = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ "*" ]; };
        };
      });
    };

    config = {
      # the ironshark.org catch-all all lands in xin@'s mailbox
      tn.mailArchive.accounts.ironshark = {
        host = "imap.gmail.com";
        user = "xin@ironshark.org";
        passwordSecret = "smtp-password";   # Workspace app password, IMAP too
        # labels are folders; leave out Gmail's views and junk
        patterns = [ "*" "![Gmail]/Spam" "![Gmail]/Trash" "![Gmail]/Drafts"
                     "![Gmail]/Important" "![Gmail]/Starred" ];
      };

      users.users.${user} = { isSystemUser = true; group = user; };
      users.groups.${user} = {};
      systemd.tmpfiles.rules = [
        "d ${root}        0750 ${user} ${user} -"
        "d ${root}/.inbox 0750 ${user} ${user} -"   # Dovecot needs an INBOX; the archive's is empty
        "d ${index}       0750 ${user} ${user} -"
      ] ++ map (n: "d ${root}/${n} 0750 ${user} ${user} -") (lib.attrNames cfg.accounts);   # mbsync won't create its store

      systemd.services.mail-archive-sync = {
        description = "Pull mail into the archive";
        after    = [ "network-online.target" "zfs-mount.service" ];
        wants    = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [ root ];
        serviceConfig = {
          Type  = "oneshot";
          User  = user;
          Group = user;
          LoadCredential = lib.mapAttrsToList (n: a: "${n}:${config.sops.secrets.${a.passwordSecret}.path}") cfg.accounts;
          ExecStart = "${lib.getExe' pkgs.isync "mbsync"} -c ${mbsyncrc} --all";
          # index what just arrived, so searches stay instant
          ExecStartPost = "+${lib.getExe' config.services.dovecot2.package "doveadm"} -c /etc/dovecot/dovecot.conf index -u xin -q '*'";
          Nice = 10;
        };
      };
      systemd.timers.mail-archive-sync = {
        wantedBy    = [ "timers.target" ];
        timerConfig = { OnCalendar = "*:0/15"; Persistent = true; };
      };

      # ── Dovecot: the archive over IMAP, read-only ─────────────────────
      sops.secrets.mail-archive-passwd = { owner = "dovecot2"; };   # xin:{BLF-CRYPT}...
      services.dovecot2 = {
        enable    = true;
        enablePAM = false;
        package   = pkgs.dovecot;   # 2.4; stateVersion 23.11 would pick 2.3
        settings = let pkg = config.services.dovecot2.package; in {
          dovecot_config_version  = pkg.version;
          dovecot_storage_version = pkg.version;
          protocols = [ "imap" ];

          ssl = "required";
          ssl_server_cert_file = "${acme}/fullchain.pem";
          ssl_server_key_file  = "${acme}/key.pem";
          "service imap-login" = {
            "inet_listener imap"  = { port = 0; };
            "inet_listener imaps" = { port = 993; ssl = true; };
          };

          "passdb passwd-file" = { passwd_file_path = config.sops.secrets.mail-archive-passwd.path; };
          "userdb static" = {
            fields = { uid = user; gid = user; home = "${index}/%{user}"; };
          };

          mail_driver = "maildir";
          mail_path   = root;
          mail_index_path = "${index}/%{user}";
          mail_inbox_path = "${root}/.inbox";
          mailbox_list_layout = "fs";

          # read-only: look, read, and mark seen/flagged; no delete or move
          mail_plugins = { acl = true; fts = true; fts_flatcurve = true; };
          acl_driver = "vfile";
          "acl owner" = { rights = "lrws"; };

          # substring search also finds Chinese words, which this build has
          # no language support (segmentation) for
          "fts flatcurve" = { substring_search = true; };
          fts_autoindex = true;
          fts_decoder_driver   = "tika";
          fts_decoder_tika_url = "http://127.0.0.1:9998/tika/";   # Tika takes PUTs at /tika/ (/ is 405)
          "language en" = { default = true; };
          language_tokenizers = [ "generic" "email-address" ];
        };
      };
      # the wildcard cert's key is root/nginx-only; dovecot reads it as root
      systemd.services.dovecot = {
        after = [ "acme-ironshark.org.service" ];
        wants = [ "acme-ironshark.org.service" ];
      };
      security.acme.certs."ironshark.org".reloadServices = [ "dovecot.service" ];

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 993 ];
      tn.web.extraNames = [ "mail" ];
    };
  };
}
