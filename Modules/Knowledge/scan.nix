{ inputs, ... }: {
  flake.nixosModules.Tn-scan = { config, pkgs, lib, ... }:
    let
      # Upload to Paperless on Akmon (https://docs.ironshark.org, Tn-paperless)
      # through its REST API; Paperless titles, tags and files it from there.
      paperless-add = pkgs.writeShellApplication {
        name = "paperless-add";
        runtimeInputs = with pkgs; [ curl coreutils ];
        text = ''
          if [ $# -eq 0 ] || [ "$1" = -h ] || [ "$1" = --help ]; then
            echo "Usage: paperless-add FILE...   (PDF, image, Office doc, .eml)"
            exit 0
          fi
          pw=$(cat ${config.sops.secrets.paperless-admin-password.path})
          rc=0
          for f in "$@"; do
            [ -f "$f" ] || { echo "paperless-add: no such file: $f" >&2; rc=1; continue; }
            # the login goes in on stdin, not on the command line
            if curl -fsS --max-time 600 -K - -o /dev/null \
                 -F "document=@$f" https://docs.ironshark.org/api/documents/post_document/ \
                 <<<"user = \"xin:$pw\""; then
              echo "paperless-add: sent $f"
            else
              echo "paperless-add: could not send $f (is Akmon reachable?)" >&2; rc=1
            fi
          done
          exit "$rc"
        '';
      };

      # sane-airscan ships an airscan.conf that is entirely commented out.
      # mkSaneConfig symlinks each backend's config into one tree and lets
      # later paths overwrite earlier ones, so listing this derivation after
      # sane-airscan in extraBackends replaces that example file with ours.
      airscanConf = pkgs.writeTextFile {
        name = "sane-airscan-config";
        destination = "/etc/sane.d/airscan.conf";
        text = ''
          [options]
          discovery    = enable
          protocol     = auto

          # The MFC-J1360DW advertises both eSCL (_uscan._tcp) and WSD. With
          # WSD on, airscan lists the same scanner twice and the two probes
          # race, so the "eN" index in the device name shifts between runs and
          # a device string that worked a moment ago fails to open. eSCL alone
          # is stable and is the protocol the scanner actually does well.
          ws-discovery = off

          # Name devices after the hardware model rather than the DNS-SD
          # service name, so GUIs show "Brother MFC-J1360DW".
          model        = hardware
        '';
      };

      scan = pkgs.writeShellApplication {
        name = "scan";
        runtimeInputs = with pkgs; [
          paperless-add
          sane-backends
          img2pdf
          ocrmypdf
          unpaper
          coreutils
        ];
        text = ''
          # SANE's backend search path and config dir normally arrive through
          # environment.sessionVariables, which is missing in non-login shells
          # and systemd units. Set them here so the script works anywhere,
          # while still allowing an override for debugging.
          export SANE_CONFIG_DIR="''${SANE_CONFIG_DIR:-/etc/sane-config}"
          export LD_LIBRARY_PATH="/etc/sane-libs''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

          scan_dir="''${SCAN_DIR:-$HOME/Downloads}"
          source="Flatbed"
          resolution=300
          mode="Gray"
          device=""
          output=""
          ocr=1
          clean=0
          keep_images=0
          name=""
          paperless="''${SCAN_PAPERLESS:-0}"

          usage() {
            cat <<'EOF'
          Usage: scan [options] [name]

          Scans to a dated, OCR'd PDF in ~/Downloads (override with $SCAN_DIR).
          An optional [name] is appended to the filename.

          Options:
            -a, --adf              feed from the ADF and scan every sheet
            -r, --resolution DPI   100, 200, 300 or 600  (default: 300)
            -m, --mode MODE        color or gray         (default: gray)
            -c, --color            shorthand for --mode color
            -C, --clean            run unpaper over the pages before OCR
            -N, --no-ocr           skip OCR, leave a plain image PDF
            -P, --paperless        send it to Paperless (docs.ironshark.org);
                                   the local copy is kept only if that fails
                                   (also: SCAN_PAPERLESS=1)
            -k, --keep-images      keep the raw PNGs next to the PDF
            -d, --device DEV       SANE device (default: first airscan device)
            -o, --output PATH      write to this exact path
            -l, --list             list detected scanners and exit
            -h, --help             show this help
          EOF
          }

          # Resolve a device name fresh on every run: airscan's "eN" index is
          # assigned in discovery order, so it must never be hardcoded.
          find_device() {
            local list
            list=$(scanimage --formatted-device-list '%d%n' 2>/dev/null) || true
            grep -m1 '^airscan:' <<<"$list" && return 0
            grep -m1 . <<<"$list" || true
          }

          while [ $# -gt 0 ]; do
            case "$1" in
              -a|--adf)         source="ADF" ;;
              -r|--resolution)  resolution="$2"; shift ;;
              -m|--mode)        mode="$2"; shift ;;
              -c|--color)       mode="color" ;;
              -C|--clean)       clean=1 ;;
              -N|--no-ocr)      ocr=0 ;;
              -P|--paperless)   paperless=1 ;;
              -k|--keep-images) keep_images=1 ;;
              -d|--device)      device="$2"; shift ;;
              -o|--output)      output="$2"; shift ;;
              -l|--list)        scanimage --formatted-device-list '%d  (%v %m)%n'; exit 0 ;;
              -h|--help)        usage; exit 0 ;;
              -*)               echo "scan: unknown option $1" >&2; usage >&2; exit 2 ;;
              *)                name="$1" ;;
            esac
            shift
          done

          case "''${mode,,}" in
            color) mode="Color" ;;
            gray|grey|grayscale) mode="Gray" ;;
            *) echo "scan: mode must be color or gray (got '$mode')" >&2; exit 2 ;;
          esac

          case "$resolution" in
            100|200|300|600) ;;
            *) echo "scan: resolution must be 100, 200, 300 or 600 (got '$resolution')" >&2; exit 2 ;;
          esac

          if [ -z "$device" ]; then
            device=$(find_device || true)
            if [ -z "$device" ]; then
              echo "scan: no scanner found. Check that it is powered on and on the" >&2
              echo "      same network, then try: scan --list" >&2
              exit 1
            fi
          fi

          if [ -z "$output" ]; then
            mkdir -p "$scan_dir"
            stamp=$(date +%Y-%m-%d-%H%M%S)
            if [ -n "$name" ]; then
              output="$scan_dir/$stamp-$name.pdf"
            else
              output="$scan_dir/$stamp.pdf"
            fi
          else
            mkdir -p "$(dirname "$output")"
          fi

          workdir=$(mktemp -d)
          trap 'rm -rf "$workdir"' EXIT

          echo "scan: $device -- $source, ''${resolution}dpi, $mode"

          if [ "$source" = "ADF" ]; then
            # scanimage exits non-zero once the feeder runs dry, which is the
            # normal way a batch ends; judge success by the pages produced.
            scanimage --device-name "$device" --source ADF \
              --resolution "$resolution" --mode "$mode" \
              --format=png --batch="$workdir/page-%03d.png" || true
          else
            scanimage --device-name "$device" --source Flatbed \
              --resolution "$resolution" --mode "$mode" \
              --format=png --output-file "$workdir/page-001.png" || true
          fi

          shopt -s nullglob
          pages=("$workdir"/page-*.png)
          shopt -u nullglob

          if [ ''${#pages[@]} -eq 0 ]; then
            echo "scan: the scanner produced no pages" >&2
            [ "$source" = "ADF" ] && echo "      (is there paper in the feeder?)" >&2
            exit 1
          fi

          echo "scan: scanned ''${#pages[@]} page(s), building PDF"

          # scanimage's PNGs carry no pHYs chunk, so state the DPI explicitly
          # or img2pdf guesses 72 and the page comes out letter-sized wrong.
          img2pdf --imgsize "''${resolution}dpi" -o "$workdir/raw.pdf" "''${pages[@]}"

          if [ "$ocr" -eq 1 ]; then
            ocr_args=(--deskew --rotate-pages --optimize 1 --skip-text --quiet)
            [ "$clean" -eq 1 ] && ocr_args+=(--clean)
            ocrmypdf "''${ocr_args[@]}" "$workdir/raw.pdf" "$output"
          else
            cp "$workdir/raw.pdf" "$output"
          fi

          if [ "$keep_images" -eq 1 ]; then
            cp "''${pages[@]}" "$(dirname "$output")/"
          fi

          echo "scan: wrote $output"

          if [ "$paperless" = 1 ]; then
            if paperless-add "$output"; then
              rm -f "$output"
            else
              echo "scan: kept $output; send it later with: paperless-add $output" >&2
            fi
          fi
        '';
      };

      # The ADF is the only thing that differs from a flatbed run, so this is a
      # front end over `scan --adf` rather than a second copy of the pipeline:
      # one place to fix the PNG -> img2pdf -> ocrmypdf chain. The scanner
      # advertises only Flatbed and ADF (no duplex), so batches are simplex.
      multi-scan = pkgs.writeShellApplication {
        name = "multi-scan";
        runtimeInputs = [ scan ];
        text = ''
          for arg in "$@"; do
            case "$arg" in
              -h|--help)
                cat <<'EOF'
          Usage: multi-scan [options] [name]

          Feeds every sheet in the top tray (ADF) and collects them into one
          dated, OCR'd PDF in ~/Downloads (override with $SCAN_DIR).
          An optional [name] is appended to the filename.

          Equivalent to `scan --adf`; every scan option is accepted here too:

            -r, --resolution DPI   100, 200, 300 or 600  (default: 300)
            -m, --mode MODE        color or gray         (default: gray)
            -c, --color            shorthand for --mode color
            -C, --clean            run unpaper over the pages before OCR
            -N, --no-ocr           skip OCR, leave a plain image PDF
            -P, --paperless        send it to Paperless instead of keeping it
            -k, --keep-images      keep the raw PNGs next to the PDF
            -d, --device DEV       SANE device (default: first airscan device)
            -o, --output PATH      write to this exact path
            -l, --list             list detected scanners and exit
            -h, --help             show this help
          EOF
                exit 0 ;;
            esac
          done

          exec scan --adf "$@"
        '';
      };

    in {
      sops.secrets.paperless-admin-password = { owner = "xin"; };

      hardware.sane = {
        enable = true;
        extraBackends = [ pkgs.sane-airscan airscanConf ];

        # escl is sane-backends' own driverless backend. It finds the same
        # scanner airscan does, so every device appears twice, and while
        # probing it fetches the printer's web root and dumps the HTML to
        # stdout -- which corrupts the output of `scanimage -L`. v4l offers
        # the built-in webcam as a "scanner"; nothing here wants that.
        disabledDefaultBackends = [ "escl" "v4l" ];
      };

      # airscan discovers eSCL scanners over DNS-SD, which needs avahi. It is
      # already enabled in Tn-network; mkDefault keeps this module standalone
      # without fighting that definition.
      services.avahi.enable = lib.mkDefault true;

      environment.systemPackages = with pkgs; [
        simple-scan   # quick single/multi-page scans straight to PDF
        naps2         # saved profiles, ADF batches, built-in OCR
        ocrmypdf      # add a text layer to any PDF
        tesseract     # OCR engine behind ocrmypdf (129 languages)
        img2pdf       # lossless image -> PDF
        unpaper       # page cleanup for ocrmypdf --clean
        qpdf          # split/merge/rotate scanned PDFs
        scan
        multi-scan    # `scan --adf` under its own name
        paperless-add
      ];
    };
}
