{ inputs, ... }: {
  # Akmon's side of remote building: a locked-down `nix-builder` account that
  # other machines' nix daemons use over the tailnet, plus a signed binary
  # cache (harmonia) serving everything in the store. Clients: Tn-build-client.
  flake.nixosModules.Tn-build-host = { config, pkgs, ... }: {

    users.groups.nix-builder = {};
    users.users.nix-builder = {
      isSystemUser = true;
      group        = "nix-builder";
      # sshd needs a real shell to run the forced command
      shell        = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = [
        # root's nix-daemon on Kvasir; can only speak the nix store protocol
        ''command="${config.nix.package}/bin/nix-daemon --stdio",restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIrBP2MU9nwGzszIYQw+8iND0s5+phMAH16i3/+qAMmZ nix-daemon@Kvasir''
      ];
    };

    # remote builds hand over unsigned .drv inputs
    nix.settings.trusted-users = [ "nix-builder" ];

    sops.secrets.harmonia-signing-key = {};

    services.harmonia.cache = {
      enable       = true;
      signKeyPaths = [ config.sops.secrets.harmonia-signing-key.path ];
      settings = {
        bind     = "[::]:5000";
        priority = 30;                     # ahead of cache.nixos.org (40)
      };
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 5000 ];
  };
}
