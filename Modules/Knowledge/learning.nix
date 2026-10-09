{ inputs, ... }: {
  flake.nixosModules.Tn-learning = { pkgs, config, ... }:
  let
    # see the nixpkgs-zotero input in flake.nix
    zotero = (import inputs.nixpkgs-zotero {
      inherit (pkgs.stdenv.hostPlatform) system;
    }).zotero;

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
      zotero   # pinned, see above
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

          # Javelin's HID interface (WebHID tools), for Javelin boards only: not
          # every keyboard and security key. Javelin's product IDs are 0x40xx;
          # the vendor ID depends on the board (javelin-steno-pico config/*.h).
          KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="9000|feed|4653|8d1d|7fce|2e8a", ATTRS{idProduct}=="40??", TAG+="uaccess"
        '';
        destination = "/etc/udev/rules.d/70-javelin.rules";
      })
    ];

  };
}
