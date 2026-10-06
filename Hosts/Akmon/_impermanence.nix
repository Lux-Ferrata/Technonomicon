# Akmon: ZFS root that rolls back to an empty snapshot on every boot.
# Anything not listed under environment.persistence (or living on /nix or a
# data pool) is gone after a reboot -- that's the point.
{ config, pkgs, ... }: {

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes         = "/dev/disk/by-id";
  networking.hostId         = "c0fbb727";

  # "fast": the Samsung 990 EVO Plus 2TB, whole-disk single-vdev pool for
  # service data. fast/srv -> /srv (native zfs mount, not in fstab, so a missing
  # pool never blocks boot); fast/reserved holds 50G headroom. Deliberately NOT
  # in _disko.nix so an OS reinstall can't touch it.
  boot.zfs.extraPools = [ "fast" ];

  services.zfs = {
    autoScrub.enable = true;
    trim.enable      = true;
  };

  # no swap partition (swap on ZFS is a bad idea); compressed RAM swap instead
  zramSwap.enable = true;

  # keep the fallback ESP on sys1 bootable
  boot.loader.systemd-boot.extraInstallCommands = ''
    if ${pkgs.util-linux}/bin/mountpoint -q /boot-fallback; then
      ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot-fallback/
    fi
  '';

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback-root = {
    description = "Roll back / to an empty snapshot";
    wantedBy    = [ "initrd.target" ];
    after       = [ "zfs-import-rpool.service" ];
    before      = [ "sysroot.mount" ];
    path        = [ config.boot.zfs.package ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r rpool/local/root@blank";
  };

  fileSystems."/persist".neededForBoot = true;

  # host keys live directly in /persist: sops needs them before the
  # impermanence bind mounts exist
  services.openssh.hostKeys = [
    { path = "/persist/etc/ssh/ssh_host_ed25519_key"; type = "ed25519"; }
  ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"            # stable uids/gids
      "/var/lib/systemd"          # timers, coredumps
      "/var/lib/tailscale"        # tailnet identity
      "/var/lib/iwd"              # wifi
      "/etc/NetworkManager/system-connections"
      "/var/lib/docker"
      "/var/db/sudo"              # "lectured" flag, else the sudo lecture every boot
    ];
    files = [ "/etc/machine-id" ];

    users.xin.directories = [
      { directory = ".ssh"; mode = "0700"; }   # known_hosts
      ".local/share/atuin"
      ".local/share/fish"
      ".local/share/zoxide"
    ];
  };
}
