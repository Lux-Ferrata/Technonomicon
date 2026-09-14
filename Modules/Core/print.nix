{ inputs, ... }: {
  flake.nixosModules.Tn-print = { pkgs, ... }: {

    services.printing = {
      enable = true;

      # cups-browsed does not create real queues: it watches DNS-SD and
      # synthesizes `implicitclass://` queues at runtime, then tears them down
      # whenever it stops or discovery lapses -- so the printer vanished after
      # every reboot, suspend, or Wi-Fi blip and came back with a fresh queue.
      # The MFC-J1360DW speaks IPP Everywhere (IPP 2.0, image/urf +
      # image/pwg-raster, mopria-certified 2.2), so CUPS can drive it directly
      # and the permanent queue below replaces what browsed was faking.
      # Upstream has deprecated cups-browsed as well; it is gone in
      # cups-filters 2.x.
      browsed.enable = false;
    };

    # A declarative, permanent queue. `model = "everywhere"` makes CUPS build
    # the PPD from the printer's own IPP attributes, so there is no vendor
    # driver to install or keep working. Addressed by mDNS name rather than IP
    # so a new DHCP lease can't break it (Tn-network sets nssmdns4).
    hardware.printers = {
      ensurePrinters = [
        {
          name = "Brother_MFC_J1360DW";
          description = "Brother MFC-J1360DW";
          location = "Home";
          deviceUri = "ipp://BRWDC567B3CAB4A.local:631/ipp/print";
          model = "everywhere";
          # No ppdOptions: the printer already reports the defaults we want
          # (media-default na_letter_8.5x11in, print-color-mode-default color).
        }
      ];

      # There was no system default destination, so applications had nothing
      # preselected in their print dialog.
      ensureDefaultPrinter = "Brother_MFC_J1360DW";
    };
  };
}
