{ ... }: {
  flake.nixosModules.Tn-provenance = { pkgs, ... }:
    let
      vault    = "/home/xin/Grimoire";
      signKey  = "/home/xin/.ssh/grimoire_provenance_ed25519";
      signId   = "provenance@grimoire";
      minInterval = "600"; # v2: min seconds between snapshots of one file (throttle autosave)

      deps = with pkgs; [
        opentimestamps-client
        openssh
        coreutils   # provides stdbuf (v2)
        gawk
        findutils
        inotify-tools
      ];

      # Shared library: env resolution + is_flagged + snapshot. Interpolated (DRY at
      # the Nix level, no runtime `source`) into both the capture daemon and the sweep.
      libSh = ''
        VAULT="''${GRIMOIRE_VAULT:-$HOME/Grimoire}"
        STORE="$VAULT/.provenance"
        KEY="''${GRIMOIRE_SIGN_KEY:-$HOME/.ssh/grimoire_provenance_ed25519}"
        HOST="$(uname -n)"; HOST="''${HOST%%.*}"
        MIN_INTERVAL="''${GRIMOIRE_MIN_INTERVAL:-600}"

        is_flagged() {  # true iff YAML frontmatter has `provenance: true`
          awk '
            NR==1 && $0!="---" { exit 1 }
            NR>1 && /^---[[:space:]]*$/ { exit (found?0:1) }
            /^provenance:[[:space:]]*true[[:space:]]*$/ { found=1 }
            END { exit (found?0:1) }
          ' "$1"
        }

        snapshot() {
          local f="$1"
          [[ "$f" == *.md ]] || return 0
          case "$f" in
            "$STORE"/*|"$VAULT"/.git/*|"$VAULT"/.obsidian/*|"$VAULT"/.trash/*) return 0 ;;
          esac
          [[ -f "$f" ]] || return 0
          is_flagged "$f" || return 0

          local rel="''${f#"$VAULT"/}"
          local slug="''${rel//\//__}"; slug="''${slug%.md}"
          local dir="$STORE/$slug"; mkdir -p "$dir"

          local h now; h="$(sha256sum "$f" | cut -d' ' -f1)"; now="$(date +%s)"
          # epoch-prefixed names sort chronologically, so the last glob match is newest.
          local last="" c
          for c in "$dir"/*.md; do [[ -e "$c" ]] && last="$c"; done
          if [[ -n "$last" ]]; then
            # content-hash dedup: identical content never re-snapshots
            [[ "$(sha256sum "$last" | cut -d' ' -f1)" == "$h" ]] && return 0
            # v2 min-interval throttle: coalesce rapid autosaves. A changed-but-throttled
            # file is captured later by the sweep once the interval elapses.
            local last_ts="''${last##*/}"; last_ts="''${last_ts%%.*}"
            (( now - last_ts < MIN_INTERVAL )) && return 0
          fi

          local base; base="$dir/$now.$HOST.md"
          cp "$f" "$base"
          ssh-keygen -Y sign -f "$KEY" -n file "$base" >/dev/null 2>&1 || true
          printf 'captured %s\n' "$base"
          # anchoring (.ots) is deferred to the reconcile timer.
        }
      '';

      # Long-running watcher: snapshot + sign flagged notes on save. Offline-safe,
      # no network. Anchoring (ots) is deferred to the reconcile timer.
      capture = pkgs.writeShellApplication {
        name = "grimoire-provenance-capture";
        runtimeInputs = deps;
        # daemon: drop errexit so one bad file never kills the watch loop
        bashOptions = [ "nounset" "pipefail" ];
        text = ''
          ${libSh}
          SIGN_ID="''${GRIMOIRE_SIGN_ID:-provenance@grimoire}"

          # register this host's PUBLIC key in the synced signer set.
          # one file per host => Syncthing never sees a conflicting edit.
          mkdir -p "$STORE/signers"
          if [ -f "$KEY.pub" ]; then
            printf '%s %s\n' "$SIGN_ID" "$(cut -d' ' -f1-2 "$KEY.pub")" \
              > "$STORE/signers/$HOST.pub"
          fi

          # v2: stdbuf -oL line-buffers events so captures are near-instant.
          # v2: also watch moved_to/create -> catch atomic-rename saves (Syncthing
          #     delivers incoming files via temp+rename; Obsidian itself is close_write).
          exec stdbuf -oL inotifywait -m -r \
            -e close_write -e moved_to -e create \
            --format '%w%f' \
            --exclude '(/\.git/|/\.obsidian/|/\.trash/|/\.provenance/)' "$VAULT" |
          while read -r path; do snapshot "$path" || true; done
        '';
      };

      # v2: sweep timer job. Snapshot any flagged note whose live content differs from
      # its newest snapshot (same dedup + throttle). Guarantees the settled/final state
      # of an editing session is captured, catches any missed atomic-rename edit, and
      # is resilient if the capture daemon is down.
      sweep = pkgs.writeShellApplication {
        name = "grimoire-provenance-sweep";
        runtimeInputs = deps;
        bashOptions = [ "nounset" "pipefail" ];
        text = ''
          ${libSh}
          [[ -d "$VAULT" ]] || exit 0
          find "$VAULT" -type f -name '*.md' \
            -not -path "$VAULT/.git/*"   -not -path "$VAULT/.obsidian/*" \
            -not -path "$VAULT/.trash/*" -not -path "$VAULT/.provenance/*" \
            -print0 | while IFS= read -r -d "" f; do
              if is_flagged "$f"; then snapshot "$f" || true; fi
            done
          exit 0
        '';
      };

      # Timer job: anchor snapshots to Bitcoin via OpenTimestamps. Needs network,
      # idempotent, self-healing (offline just means "try next tick").
      reconcile = pkgs.writeShellApplication {
        name = "grimoire-provenance-reconcile";
        runtimeInputs = deps;
        bashOptions = [ "nounset" "pipefail" ];
        text = ''
          VAULT="''${GRIMOIRE_VAULT:-$HOME/Grimoire}"
          STORE="$VAULT/.provenance"
          STAMP_SIG="''${GRIMOIRE_STAMP_SIG:-1}"
          HOST="$(uname -n)"; HOST="''${HOST%%.*}"
          [[ -d "$STORE" ]] || exit 0

          # v2: operate ONLY on this host's own snapshots. The filename encodes the
          # creating host, so each machine mutates only the .ots it created -> no
          # Syncthing conflict on the (mutable, shared) .ots files. Foreign-host
          # proofs arrive already-complete via sync and are never touched locally.

          # 1) stamp any of THIS host's snapshots (and its .sig) lacking a .ots
          find "$STORE" -type f -name "*.$HOST.md" -print0 | while IFS= read -r -d "" f; do
            [[ -e "$f.ots" ]] || ots stamp "$f" || true
            if [[ "$STAMP_SIG" = 1 && -e "$f.sig" ]]; then
              [[ -e "$f.sig.ots" ]] || ots stamp "$f.sig" || true
            fi
          done

          # 2) upgrade THIS host's pending .ots (no-op once confirmed; needs network)
          find "$STORE" -type f \( -name "*.$HOST.md.ots" -o -name "*.$HOST.md.sig.ots" \) \
            -print0 | xargs -0 -r -n1 ots upgrade >/dev/null 2>&1 || true

          exit 0   # always succeed so the timer keeps rescheduling
        '';
      };

      # Helper: verify one snapshot's authorship + timestamp.
      verify = pkgs.writeShellApplication {
        name = "grimoire-provenance-verify";
        runtimeInputs = deps;
        text = ''
          f="$1"   # path to a snapshot .md
          VAULT="''${GRIMOIRE_VAULT:-$HOME/Grimoire}"
          STORE="$VAULT/.provenance"
          SIGN_ID="''${GRIMOIRE_SIGN_ID:-provenance@grimoire}"

          ALLOWED="$(mktemp)"
          trap 'rm -f "$ALLOWED"' EXIT
          if [[ -n "''${GRIMOIRE_ALLOWED_SIGNERS:-}" && -f "''${GRIMOIRE_ALLOWED_SIGNERS:-}" ]]; then
            cat "$GRIMOIRE_ALLOWED_SIGNERS" > "$ALLOWED"
          else
            cat "$STORE"/signers/*.pub > "$ALLOWED"
          fi

          echo "== signature (who) =="
          ssh-keygen -Y verify -f "$ALLOWED" -I "$SIGN_ID" -n file -s "$f.sig" < "$f"
          echo "== timestamp (when) =="
          ots verify "$f.ots"
        '';
      };

      # Helper: bundle one note's proof trail for handover (self-contained).
      package = pkgs.writeShellApplication {
        name = "grimoire-provenance-package";
        runtimeInputs = deps;
        text = ''
          slug="$1"                         # e.g. Reference__University of Arizona Personal Statement
          VAULT="''${GRIMOIRE_VAULT:-$HOME/Grimoire}"
          STORE="$VAULT/.provenance"
          out="''${2:-$slug-proof.tar.gz}"

          tar -C "$STORE" -czf "$out" "signers" "$slug"
          echo "wrote $out"
          echo "self-contained: it holds every snapshot for '$slug' plus signers/*.pub"
          echo "verifier: extract, then per snapshot run"
          echo "  ssh-keygen -Y verify -f <(cat signers/*.pub) -I ${signId} -n file -s <snap>.sig < <snap>"
          echo "  ots verify <snap>.ots"
        '';
      };

      # env for capture + sweep (both run snapshot())
      captureEnv = [
        "GRIMOIRE_VAULT=${vault}"
        "GRIMOIRE_SIGN_KEY=${signKey}"
        "GRIMOIRE_SIGN_ID=${signId}"
        "GRIMOIRE_MIN_INTERVAL=${minInterval}"
      ];
    in {
      home-manager.users.xin = { lib, ... }: {
        home.packages = [ capture sweep reconcile verify package ];

        # dedicated, unencrypted signing key — never added to any authorized_keys.
        # per-machine; the public half is published to the synced signer set at
        # daemon startup so snapshots verify across all machines.
        home.activation.grimoireProvenanceKey =
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            KEY="$HOME/.ssh/grimoire_provenance_ed25519"
            if [ ! -f "$KEY" ]; then
              $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
              $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" \
                -C grimoire-provenance -f "$KEY"
              $DRY_RUN_CMD chmod 600 "$KEY"
            fi
          '';

        systemd.user.services.grimoire-provenance-watch = {
          Unit = {
            Description = "Grimoire provenance capture (snapshot+sign flagged notes on save)";
            After = [ "default.target" ];
          };
          Service = {
            ExecStart = "${capture}/bin/grimoire-provenance-capture";
            Restart = "always";
            RestartSec = 5;
            Environment = captureEnv;
          };
          Install.WantedBy = [ "default.target" ];
        };

        # v2: idle-flush / catch-up sweep
        systemd.user.services.grimoire-provenance-sweep = {
          Unit.Description = "Grimoire provenance sweep (capture settled/missed states)";
          Service = {
            Type = "oneshot";
            ExecStart = "${sweep}/bin/grimoire-provenance-sweep";
            Environment = captureEnv;
          };
        };

        systemd.user.timers.grimoire-provenance-sweep = {
          Unit.Description = "Periodic Grimoire provenance sweep";
          Timer = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        systemd.user.services.grimoire-provenance-anchor = {
          Unit.Description = "Grimoire provenance anchor (ots stamp/upgrade)";
          Service = {
            Type = "oneshot";
            ExecStart = "${reconcile}/bin/grimoire-provenance-reconcile";
            Environment = [
              "GRIMOIRE_VAULT=${vault}"
              "GRIMOIRE_STAMP_SIG=1"
            ];
          };
        };

        systemd.user.timers.grimoire-provenance-anchor = {
          Unit.Description = "Periodic Grimoire provenance anchoring";
          Timer = {
            OnBootSec = "3min";
            OnUnitActiveSec = "30min";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
    };
}
