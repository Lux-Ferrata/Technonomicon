{ inputs, ... }: {
  flake.nixosModules.Tn-learning = { pkgs, config, ... }:
  let
    houdini-py = pkgs.python3Packages.buildPythonPackage rec {
      pname = "houdini.py";
      version = "0.1.0";
      pyproject = true;
      build-system = [ pkgs.python3Packages.setuptools ];
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/eb/c1/25aa4ed20e108a2d82efd3787c51457a2468bed382ebec7cd0a1fd5e8d9b/houdini.py-${version}.tar.gz";
        sha256 = "0rpn4bl2hmjd7yzapgwc2allg1dp7jwrkjvyf31k974599ri1gfa";
      };
      doCheck = false;
    };

    ankdown = pkgs.python3Packages.buildPythonPackage rec {
      pname = "ankdown";
      version = "0.7.1";
      pyproject = true;
      build-system = [ pkgs.python3Packages.setuptools ];
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/5a/92/482727daa95a7a20284cd8dba8883be82ca346366c1cd0b6b8ce68854d2b/ankdown-${version}.tar.gz";
        sha256 = "0d9p4yxc4d9ad4m9k99j0rf9a5w64gp16jam27vqlvi81s5n50s7";
      };
      propagatedBuildInputs = with pkgs.python3Packages; [
        genanki misaka docopt houdini-py pygments
      ];
      doCheck = false;
    };

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
      ankdown
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
