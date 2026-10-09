{ inputs, ... }: {
  # qBittorrent (headless) at https://torrent.ironshark.org (scaffolding).
  # Downloads land in /srv/downloads (group media, so the media apps and the
  # NAS share see them). The web UI is only reached through nginx and asks
  # tailnet addresses for no login; the tailnet is the boundary. (nginx
  # forwards the client's address, so qBittorrent sees the tailnet IP, not
  # localhost. A password set in the UI wouldn't last anyway: the module
  # rewrites qBittorrent.conf on every start.)
  #
  # VPN: Akmon's internet traffic is meant to leave through Tailscale's
  # Mullvad exit node (`tailscale set --exit-node=<mullvad node>
  # --exit-node-allow-lan-access`, by hand). Set tn.torrent.vpnInterface =
  # "tailscale0" then, and qBittorrent binds to that interface only: if
  # the exit node goes away, torrents stop instead of using the home line.
  # Mullvad has no port forwarding, so peers can't connect in.
  flake.nixosModules.Tn-torrent = { config, lib, pkgs, ... }:
  let
    cfg  = config.tn.torrent;
    port = 8085;
    dl   = "/srv/downloads";
  in {
    options.tn.torrent.vpnInterface = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
      default = null;
      example = "tailscale0";
      description = "Bind all torrent traffic to this interface (VPN kill switch).";
    };

    config = {
      services.qbittorrent = {
        enable    = true;
        webuiPort = port;
        profileDir = "/var/lib/qBittorrent";
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent.Session = {
            DefaultSavePath = dl;
            TempPathEnabled = true;
            TempPath        = "${dl}/.incomplete";
          } // lib.optionalAttrs (cfg.vpnInterface != null) {
            Interface     = cfg.vpnInterface;
            InterfaceName = cfg.vpnInterface;
          };
          Preferences.WebUI = {
            Address = "127.0.0.1";
            LocalHostAuth = false;
            ReverseProxySupportEnabled = true;
            TrustedReverseProxiesList  = "127.0.0.1";
            HostHeaderValidation = false;
          };
        };
      };
      users.users.qbittorrent.extraGroups = [ "media" ];
      systemd.services.qbittorrent = {
        unitConfig.RequiresMountsFor = [ dl ];
        serviceConfig.UMask = "0002";
      };
      systemd.tmpfiles.rules = [
        "d ${dl}             2775 qbittorrent media -"
        "d ${dl}/.incomplete 2775 qbittorrent media -"
      ];
      environment.persistence."/persist".directories = [
        { directory = "/var/lib/qBittorrent"; user = "qbittorrent"; group = "qbittorrent"; mode = "0750"; }
      ];

      tn.web.vhosts.torrent = { inherit port; maxBody = "10m"; };
    };
  };
}
