{ inputs, ... }: {
  flake.nixosModules.Tn-virtualization = { pkgs, ... }: {

    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          swtpm.enable = true;
        };
      };
      docker.enable = true;
      spiceUSBRedirection.enable = true;
    };

    users.users.xin.extraGroups = [
      "libvirtd"
      "tty"
    ];

    environment.systemPackages = with pkgs; [
      spice
      spice-gtk
      spice-protocol
      virt-viewer
      distrobox
    ];

    # Akmon's VMs (Tn-hosting) next to the local ones
    home-manager.users.xin.dconf.settings."org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris        = [ "qemu:///system" "qemu+ssh://xin@akmon/system" ];
    };

    programs = {
      virt-manager.enable = true;
      dconf.enable = true;
    };
  };
}
