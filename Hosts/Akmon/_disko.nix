# Akmon system disks: the two generic PCIe SSDs as one ZFS mirror (rpool).
# The Samsung 990 EVO Plus 2TB is NOT listed here on purpose -- it becomes the
# separate fast-storage pool once the new system is up.
#
# Each disk gets its own ESP. Only sys0's is the real /boot; sys1's is a copy
# kept in sync by extraInstallCommands (see _impermanence.nix) so firmware can
# still find a bootloader if sys0 dies.
let
  esp = mountpoint: extraOptions: {
    size    = "1G";
    type    = "EF00";
    content = {
      type         = "filesystem";
      format       = "vfat";
      inherit mountpoint;
      mountOptions = [ "fmask=0077" "dmask=0077" ] ++ extraOptions;
    };
  };

  zfsPart = {
    size    = "100%";
    content = { type = "zfs"; pool = "rpool"; };
  };

  legacy = mountpoint: {
    type    = "zfs_fs";
    inherit mountpoint;
    options.mountpoint = "legacy";
  };
in {
  disko.devices = {
    disk = {
      sys0 = {
        type    = "disk";
        device  = "/dev/disk/by-id/nvme-PCIe_SSD_21052010240373";
        content = {
          type       = "gpt";
          partitions = { ESP = esp "/boot" []; zfs = zfsPart; };
        };
      };
      sys1 = {
        type    = "disk";
        device  = "/dev/disk/by-id/nvme-PCIe_SSD_25102109400268";
        content = {
          type       = "gpt";
          partitions = { ESP = esp "/boot-fallback" [ "nofail" ]; zfs = zfsPart; };
        };
      };
    };

    zpool.rpool = {
      type    = "zpool";
      mode    = "mirror";
      options = { ashift = "12"; autotrim = "on"; };
      rootFsOptions = {
        compression = "zstd";
        acltype     = "posixacl";
        xattr       = "sa";
        atime       = "off";
        mountpoint  = "none";
      };

      datasets = {
        # wiped back to @blank on every boot
        "local/root" = legacy "/" // {
          postCreateHook = ''
            zfs list -t snapshot -H -o name | grep -q '^rpool/local/root@blank$' \
              || zfs snapshot rpool/local/root@blank
          '';
        };
        "local/nix"    = legacy "/nix";
        # everything that must survive a reboot lives here
        "safe/persist" = legacy "/persist";
        # headroom so a full pool can still be cleaned up
        "reserved" = {
          type    = "zfs_fs";
          options = { mountpoint = "none"; reservation = "20G"; };
        };
      };
    };
  };
}
