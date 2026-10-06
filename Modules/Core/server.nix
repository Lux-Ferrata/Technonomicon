{ inputs, ... }: {
  flake.nixosModules.Tn-server = { ... }: {

    # headless box, reached and deployed to from Kvasir over the tailnet
    services.tailscale = {
      enable       = true;
      openFirewall = true;   # direct UDP instead of DERP relays
    };

    # sshd only answers on the tailnet; hardening settings live in Tn-network
    services.openssh = {
      enable       = true;
      openFirewall = false;
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

    users.users.xin.openssh.authorizedKeys.keys = [
      # xin@Kvasir
      "KVASIR_PUBKEY_PLACEHOLDER"
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
