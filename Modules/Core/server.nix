{ inputs, ... }: {
  flake.nixosModules.Tn-server = { config, lib, pkgs, ... }: {

    # Kvasir's terminal is Ghostty; without its terminfo here, full-screen
    # tools (btop, nvim) over ssh fall back or refuse to start
    environment.systemPackages = [ pkgs.ghostty.terminfo ];

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

    # generations (and the store paths only they use) go after 30 days, not
    # Tn-nix's 6: a month of rollback targets (deploys and the weekly
    # auto-upgrade) stays on disk; the boot menu still shows only the newest 10
    programs.nh.clean.extraArgs = lib.mkForce "--keep-since 30d --keep 3";
    # the repo isn't checked out here (it isn't in the synced ~/Projects):
    # nh uses the branch the auto-upgrade follows
    programs.nh.flake = lib.mkForce "git+http://127.0.0.1:3000/xin/Technonomicon.git?ref=working";
  };
}
