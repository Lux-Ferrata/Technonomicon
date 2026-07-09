{ inputs, ... }: {
  flake.nixosModules.Tn-learning = { pkgs, config, ... }: {

    environment.systemPackages = with pkgs; [
      hledger
      hledger-ui
      hledger-web
      fava
      beancount
      gnucash
      visidata
      # datasette  # broken: asgi-csrf dep marked broken in nixpkgs (2026-07); re-enable when fixed
      anki-bin
      zotero
      foliate
      zathura
      pdfannots2json
      wtfutil
      (symlinkJoin {
        name = "rnote-wrapped";
        paths = [ rnote ];
        buildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/rnote \
        --set GDK_BACKEND x11
        '';
      })
    ];

    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "javelin-udev-rules";
        text = ''
          # RP2040 Bootloader (for flashing firmware)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0003", TAG+="uaccess"

      # Generic HID (for Javelin WebHID Tools)
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", TAG+="uaccess"
        '';
        destination = "/etc/udev/rules.d/70-javelin.rules";
      })
    ];

  };
}
