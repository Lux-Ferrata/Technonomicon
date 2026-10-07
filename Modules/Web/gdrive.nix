{ ... }: {
  # Google Drive (xin@ironshark.org) from the terminal: the rclone remote
  # `gdrive:` (rclone ls/copy/sync gdrive:...) and a mount at ~/GDrive for
  # ls, yazi, cp. Uses the Google OAuth client in sops (shared with the
  # calendar push), not rclone's shared one, which gets throttled.
  #
  # One-time: `gdrive-login` (browser sign-in; writes ~/.config/rclone).
  # The mount waits for that config, retries quietly while offline, and
  # caches file contents in ~/.cache/rclone.
  flake.nixosModules.Tn-gdrive = { config, lib, pkgs, ... }:
  let
    secrets = "${config.users.users.xin.home}/Projects/Technonomicon/_secrets.yaml";
    rclone  = lib.getExe pkgs.rclone;

    gdriveLogin = pkgs.writeShellApplication {
      name = "gdrive-login";
      runtimeInputs = with pkgs; [ rclone sops systemd ];
      text = ''
        get() { sops -d --extract "[\"$1\"]" ${secrets}; }
        rclone config delete gdrive 2>/dev/null || true
        rclone config create gdrive drive \
          client_id "$(get google-oauth-client-id)" \
          client_secret "$(get google-oauth-client-secret)" \
          scope drive
        rclone about gdrive:   # proves the login works
        systemctl --user restart gdrive-mount
        echo "gdrive-login: done -- ~/GDrive is mounted"
      '';
    };
  in {
    environment.systemPackages = [ pkgs.rclone gdriveLogin ];

    home-manager.users.xin = {
      systemd.user.services.gdrive-mount = {
        Unit = {
          Description = "Google Drive at ~/GDrive (rclone)";
          ConditionPathExists = "%h/.config/rclone/rclone.conf";
        };
        Service = {
          Type = "notify";
          # rclone calls the setuid fusermount3 wrapper
          Environment = "PATH=/run/wrappers/bin";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/GDrive";
          ExecStart = lib.concatStringsSep " " [
            rclone "mount" "gdrive:" "%h/GDrive"
            "--vfs-cache-mode full"
            "--vfs-cache-max-size 10G"
            "--vfs-cache-max-age 720h"
            "--dir-cache-time 5m"
            "--poll-interval 1m"
          ];
          ExecStop = "/run/wrappers/bin/fusermount3 -uz %h/GDrive";
          # offline at login: keep trying, without spamming
          Restart    = "on-failure";
          RestartSec = 60;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
