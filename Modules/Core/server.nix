{ inputs, ... }: {
  flake.nixosModules.Tn-server = { config, ... }: {

    # single-use bootstrap key; only read while the node isn't logged in yet
    sops.secrets.tailscale-authkey = {};

    # headless box, reached and deployed to from Kvasir over the tailnet
    services.tailscale = {
      enable       = true;
      openFirewall = true;   # direct UDP instead of DERP relays
      authKeyFile  = config.sops.secrets.tailscale-authkey.path;
    };

    # sshd only answers on the tailnet; hardening settings live in Tn-network
    services.openssh = {
      enable       = true;
      openFirewall = false;
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    users.users.xin.openssh.authorizedKeys.keys = [
      # xin@Kvasir
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG0xOjA5uRmGhQjFGbZsnIcKvI7g7ZIq5PiR3EeiNimO xin@Kvasir"
    ];

    # remote builds / `nix copy` from Kvasir push unsigned paths
    nix.settings.trusted-users = [ "root" "@wheel" ];

    # a server that suspends is a server that's unreachable
    systemd.targets = {
      sleep.enable        = false;
      suspend.enable      = false;
      hibernate.enable    = false;
      hybrid-sleep.enable = false;
    };

    # rollback entries without filling the ESP
    boot.loader.systemd-boot.configurationLimit = 10;
  };
}
