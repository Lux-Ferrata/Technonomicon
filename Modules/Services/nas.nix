{ inputs, ... }: {
  # Akmon as a NAS (scaffolding). Samba shares on the tailnet only, user
  # xin (sops samba-password), no guests: \\akmon\<share> from anywhere on
  # the tailnet, `smb://akmon/<share>` in a file manager, or mounted on
  # Kvasir. Shares are tn.nas.shares.<name> = path.
  #
  # The DAS (planned) becomes the "bulk" pool: set tn.nas.bulkPool and
  # syncoid starts replicating fast/srv and the persist dataset into
  # bulk/backup every night. Until then nothing replicates.
  flake.nixosModules.Tn-nas = { config, lib, pkgs, ... }:
  let
    cfg = config.tn.nas;
  in {
    options.tn.nas = {
      shares = lib.mkOption {
        type    = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Samba share name -> directory.";
      };
      bulkPool = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        example = "bulk";
        description = "ZFS pool on the DAS; enables replication into <pool>/backup.";
      };
    };

    config = lib.mkMerge [
      {
        tn.nas.shares = {
          media     = config.tn.media.root;
          downloads = "/srv/downloads";
        };

        services.samba = {
          enable = true;
          nmbd.enable = false;          # no NetBIOS browsing on a tailnet
          settings = {
            global = {
              "server string"   = "Akmon";
              interfaces        = "lo tailscale0";
              "bind interfaces only" = "yes";
              "hosts allow"     = "100.64.0.0/10 fd7a:115c:a1e0::/48 127.0.0.1 ::1";
              "hosts deny"      = "0.0.0.0/0";
              security          = "user";
              "map to guest"    = "never";
              "server min protocol" = "SMB3";
              "smb encrypt"     = "desired";
            };
          } // lib.mapAttrs (_: path: {
            inherit path;
            "read only"      = "no";
            "valid users"    = "xin";
            "force group"    = "media";
            "create mask"    = "0664";
            "directory mask" = "2775";
          }) cfg.shares;
        };
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 445 ];

        # xin's Samba password, from sops, set on every boot/deploy
        sops.secrets.samba-password = {};
        systemd.services.samba-user-xin = {
          description = "Set xin's Samba password";
          after    = [ "samba-smbd.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            LoadCredential = "pw:${config.sops.secrets.samba-password.path}";
          };
          script = ''
            pw=$(cat "$CREDENTIALS_DIRECTORY/pw")
            printf '%s\n%s\n' "$pw" "$pw" | ${pkgs.samba}/bin/smbpasswd -s -a xin
          '';
        };
        environment.persistence."/persist".directories = [ "/var/lib/samba" ];
      }

      (lib.mkIf (cfg.bulkPool != null) {
        services.syncoid = {
          enable = true;
          interval = "*-*-* 03:30:00";
          commands = {
            "fast/srv" = { target = "${cfg.bulkPool}/backup/srv"; recursive = true; };
            "rpool/safe/persist" = { target = "${cfg.bulkPool}/backup/persist"; };
          };
        };
      })
    ];
  };
}
