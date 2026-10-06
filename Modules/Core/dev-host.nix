{ inputs, ... }: {
  # Akmon's side of "Akmon is the dev box": persistent shell sessions,
  # synced projects, the editor server and code completion for Kvasir.
  # Client side: Tn-dev-client.
  flake.nixosModules.Tn-dev-host = { pkgs, ... }: {

    # shells that outlive the ssh connection (Kvasir's `ak` reattaches);
    # socket-activated user daemon, with linger so it survives the last logout
    environment.systemPackages = [ pkgs.shpool ];
    systemd.packages           = [ pkgs.shpool ];
    systemd.user.sockets.shpool.wantedBy = [ "sockets.target" ];
    users.users.xin.linger     = true;
  };
}
