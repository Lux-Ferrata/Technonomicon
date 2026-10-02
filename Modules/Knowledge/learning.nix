{ inputs, ... }: {
  flake.nixosModules.Tn-learning = { pkgs, config, ... }:
  let
    srl = pkgs.python3Packages.buildPythonPackage rec {
      pname = "srl";
      version = "20.0.0";
      pyproject = true;
      build-system = [ pkgs.python3Packages.setuptools ];
      src = pkgs.fetchFromGitHub {
        owner = "HayesBarber";
        repo = "spaced-repetition-learning";
        rev = "fb892232ab3d694348250722c696b7683c34a86a";
        hash = "sha256-jPEkjCE+kLP8p/TojY4ty7exEgjfHStFv4zmzbwJPIM=";
      };
      propagatedBuildInputs = with pkgs.python3Packages; [ rich ];
      doCheck = false;
    };
  in {

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
      srl
      zotero
      onlyoffice-desktopeditors
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
