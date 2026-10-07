{ inputs, ... }: {
  # Bitwarden, kept on Akmon as a backup (Bitwarden cloud stays the main vault):
  #
  #  - bitwarden-export: every night it signs in to Bitwarden cloud with the
  #    API key, unlocks with the master password (both in sops), and saves a
  #    password-protected export (sops bitwarden-export-password) to
  #    /srv/backup/bitwarden/. The last 60 are kept. Those files import into
  #    any Bitwarden or Vaultwarden.
  #  - Vaultwarden at https://vault.ironshark.org: a local, offline-capable
  #    copy. Refresh it by importing the newest export (Tools > Import).
  #    Admin page /admin with sops vaultwarden-admin-token.
  flake.nixosModules.Tn-vaultwarden = { config, lib, pkgs, ... }:
  let
    port    = 8222;
    backups = "/srv/backup/bitwarden";
    # stateVersion 23.11 keeps the module's old state dir name
    data    = "/var/lib/bitwarden_rs";
    bw      = lib.getExe pkgs.bitwarden-cli;
    sec     = config.sops.secrets;
  in {
    sops.secrets = {
      vaultwarden-admin-token   = {};
      bitwarden-client-id       = {};
      bitwarden-client-secret   = {};
      bitwarden-master-password = {};
      bitwarden-export-password = {};
    };
    sops.templates."vaultwarden.env".content =
      "ADMIN_TOKEN=${config.sops.placeholder.vaultwarden-admin-token}\n";

    services.vaultwarden = {
      enable = true;
      environmentFile = config.sops.templates."vaultwarden.env".path;
      config = {
        DOMAIN         = "https://vault.ironshark.org";
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT    = port;
        # on until the first account exists; then false (TODO.md)
        SIGNUPS_ALLOWED = true;
        ROCKET_LOG     = "critical";
      };
    };
    environment.persistence."/persist".directories = [
      { directory = data; user = "vaultwarden"; group = "vaultwarden"; mode = "0700"; }
      { directory = "/var/lib/bitwarden-export"; user = "bwexport"; group = "bwexport"; mode = "0700"; }
    ];
    tn.web.vhosts.vault = { inherit port; maxBody = "525m"; };   # attachments

    # ── nightly export from Bitwarden cloud ────────────────────────────
    users.users.bwexport = { isSystemUser = true; group = "bwexport"; };
    users.groups.bwexport = {};
    systemd.tmpfiles.rules = [ "d ${backups} 0700 bwexport bwexport -" ];

    systemd.services.bitwarden-export = {
      description = "Export the Bitwarden vault to ${backups}";
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = [ backups ];
      path = [ pkgs.coreutils pkgs.findutils ];
      serviceConfig = {
        Type  = "oneshot";
        User  = "bwexport";
        Group = "bwexport";
        # the CLI's local state (device id, encrypted cache) is kept, so
        # Bitwarden sees one long-lived device, not a new login each night
        StateDirectory = "bitwarden-export";
        PrivateTmp = true;
        LoadCredential = [
          "id:${sec.bitwarden-client-id.path}"
          "secret:${sec.bitwarden-client-secret.path}"
          "master:${sec.bitwarden-master-password.path}"
          "export:${sec.bitwarden-export-password.path}"
        ];
      };
      script = ''
        set -euo pipefail
        export BITWARDENCLI_APPDATA_DIR=$STATE_DIRECTORY HOME=$STATE_DIRECTORY
        c=$CREDENTIALS_DIRECTORY
        if ${bw} status | grep -q '"status":"unauthenticated"'; then
          BW_CLIENTID=$(cat $c/id) BW_CLIENTSECRET=$(cat $c/secret) ${bw} login --apikey --quiet
        fi
        BW_SESSION=$(${bw} unlock --passwordfile $c/master --raw)
        export BW_SESSION
        ${bw} sync --quiet
        out=${backups}/bitwarden-$(date +%Y-%m-%d).json
        ${bw} export --format encrypted_json --password "$(cat $c/export)" --output "$out" --quiet
        ${bw} lock --quiet
        test -s "$out"
        # keep the newest 60
        ls -1t ${backups}/bitwarden-*.json | tail -n +61 | xargs -r rm --
        echo "exported to $out"
      '';
    };
    systemd.timers.bitwarden-export = {
      wantedBy    = [ "timers.target" ];
      timerConfig = { OnCalendar = "*-*-* 02:45:00"; Persistent = true; RandomizedDelaySec = "10min"; };
    };
  };
}
