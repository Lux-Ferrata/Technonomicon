{ inputs, ... }: {
  # VMs and containers on Akmon (scaffolding).
  #   VMs:   libvirt + QEMU/KVM (UEFI, TPM). Disk images in /srv/vms. Manage
  #          from Kvasir's virt-manager (qemu+ssh://xin@akmon/system, already
  #          listed there) or Cockpit.
  #   Docker (already on, akmon.nix), Podman (alongside; `podman`, rootless
  #          too), Apptainer (`apptainer`).
  #   Cockpit at https://admin.ironshark.org: VMs, Podman containers, ZFS
  #          pools, files and logs in one web UI. Log in as xin.
  flake.nixosModules.Tn-hosting = { config, lib, pkgs, ... }:
  let
    port = 9090;
  in {
    # ── VMs ────────────────────────────────────────────────────────────
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";        # VMs start when asked, not with the host
      qemu = {
        package      = pkgs.qemu_kvm;
        swtpm.enable = true;
      };
    };
    users.users.xin.extraGroups = [ "libvirtd" ];
    systemd.tmpfiles.rules = [ "d /srv/vms 0770 root libvirtd -" ];

    # ── Containers ─────────────────────────────────────────────────────
    virtualisation.podman = {
      enable = true;
      dockerCompat = false;     # Docker owns the docker socket and CLI
      defaultNetwork.settings.dns_enabled = true;
    };
    programs.singularity = {
      enable  = true;
      package = pkgs.apptainer;
    };

    environment.persistence."/persist" = {
      directories = [ "/var/lib/libvirt" "/var/lib/containers" ];
      users.xin.directories = [ ".local/share/containers" ".config/containers" ];
    };

    # ── Cockpit ────────────────────────────────────────────────────────
    services.cockpit = {
      enable = true;
      inherit port;
      showBanner = false;
      plugins = with pkgs; [ cockpit-machines cockpit-podman cockpit-zfs cockpit-files ];
      allowed-origins = [ "https://admin.ironshark.org" ];
      settings.WebService = {
        AllowUnencrypted = true;              # TLS ends at nginx
        ProtocolHeader   = "X-Forwarded-Proto";
      };
    };
    tn.web.vhosts.admin = { inherit port; maxBody = "1g"; };   # file uploads
  };
}
