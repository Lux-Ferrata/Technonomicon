{ inputs, ... }: {
  # Akmon's side of "Akmon is the dev box": persistent shell sessions,
  # synced projects, the editor server and code completion for Kvasir.
  # Client side: Tn-dev-client.
  flake.nixosModules.Tn-dev-host = { config, pkgs, lib, ... }:
  let
    sync = import ./_sync.nix;
    home = "/srv/xin";          # fast/srv/xin: xin's synced data, survives the root wipe
  in {

    # shells that outlive the ssh connection (Kvasir's `ak` reattaches);
    # socket-activated user daemon, with linger so it survives the last logout
    environment.systemPackages = [ pkgs.shpool ];
    systemd.packages           = [ pkgs.shpool ];
    systemd.user.sockets.shpool.wantedBy = [ "sockets.target" ];
    users.users.xin.linger     = true;

    # ── Syncthing hub (topology in _sync.nix) ────────────────────────────
    # Every synced folder lands in fast/srv/xin/<dir>. The dataset is made on
    # first boot rather than by hand; sanoid already snapshots fast/srv
    # recursively, so these copies double as versioned backups.
    systemd.services.srv-xin = {
      description = "Create xin's dataset on the fast pool";
      after       = [ "zfs-mount.service" ];
      wantedBy    = [ "multi-user.target" ];
      path        = [ config.boot.zfs.package ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        zfs list fast/srv/xin >/dev/null 2>&1 || zfs create fast/srv/xin
        install -d -o xin -g users -m 0750 ${home} ${home}/.syncthing \
          ${lib.concatMapStringsSep " " (f: "${home}/${f.akmon}") (lib.attrValues sync.folders)}
      '';
    };

    # same absolute path as on Kvasir, so error paths, compile_commands.json
    # and editor state mean the same thing on both machines. Not part of
    # local-fs.target: srv-xin.service runs after sysinit, so the default
    # Before=local-fs.target would be an ordering cycle.
    systemd.mounts = [{
      what      = "${home}/Projects";
      where     = "/home/xin/Projects";
      type      = "none";
      options   = "bind";
      requires  = [ "srv-xin.service" ];
      after     = [ "srv-xin.service" ];
      before    = [ "umount.target" ];
      conflicts = [ "umount.target" ];
      wantedBy  = [ "multi-user.target" ];
      unitConfig.DefaultDependencies = false;
    }];

    # Runs as xin (not a system user) because the synced files must be xin's
    # to edit. Config + index live on the pool, identity in sops.
    sops.secrets.syncthing-akmon-cert = { owner = "xin"; };
    sops.secrets.syncthing-akmon-key  = { owner = "xin"; };

    services.syncthing = {
      enable           = true;
      dataDir          = lib.mkForce home;
      configDir        = "${home}/.syncthing";
      cert             = config.sops.secrets.syncthing-akmon-cert.path;
      key              = config.sops.secrets.syncthing-akmon-key.path;
      # only Kvasir talks to it, and only over the tailnet
      openDefaultPorts = lib.mkForce false;
      settings = {
        options = {
          globalAnnounceEnabled = false;
          localAnnounceEnabled  = false;
          relaysEnabled         = false;
          urAccepted            = -1;
        };
        devices.Kvasir = {
          id        = sync.devices.Kvasir;
          addresses = [ "tcp://kvasir:22000" ];
        };
        folders = lib.mapAttrs (id: f: {
          inherit id;
          inherit (f) label;
          path            = "${home}/${f.akmon}";
          devices         = [ "Kvasir" ];
          # first sync: take Kvasir's tree as-is, never send anything back
          type            = "receiveonly";
          fsWatcherDelayS = 1;
          ignorePatterns  = f.ignorePatterns or null;
        }) sync.folders;
      };
    };
    systemd.services.syncthing = {
      requires = [ "srv-xin.service" ];
      after    = [ "srv-xin.service" ];
    };
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [ 22000 ];
      allowedUDPPorts = [ 22000 ];
    };
  };
}
