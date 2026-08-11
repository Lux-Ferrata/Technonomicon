{ ... }: {
  flake.nixosModules.Tn-provenance = { pkgs, lib, ... }:
    let
      vault    = "/home/xin/Grimoire";
      signKey  = "/home/xin/.ssh/grimoire_provenance_ed25519";
      signId   = "provenance@grimoire";

      deps = with pkgs; [
        opentimestamps-client
        openssh
        coreutils
        gawk
        findutils
        inotify-tools
      ];

      # Long-running watcher: snapshot + sign flagged notes on save. Offline-safe,
      # no network. Anchoring (ots) is deferred to the reconcile timer.
      capture = pkgs.writeShellApplication {
        name = "grimoire-provenance-capture";
        runtimeInputs = deps;
        # daemon: drop errexit so one bad file never kills the watch loop
        bashOptions = [ "nounset" "pipefail" ];
        text = ''
          VAULT="''${GRIMOIRE_VAULT:-$HOME/Grimoire}"
          STORE="$VAULT/.provenance"
          KEY="''${GRIMOIRE_SIGN_KEY:-$HOME/.ssh/grimoire_provenance_ed25519}"
          SIGN_ID="''${GRIMOIRE_SIGN_ID:-provenance@grimoire}"
          HOST="$(uname -n)"; HOST="''${HOST%%.*}"

          # register this host's PUBLIC key in the synced signer set.
          # one file per host => Syncthing never sees a conflicting edit.
          mkdir -p "$STORE/signers"
          if [ -f "$KEY.pub" ]; then
            printf '%s %s\n' "$SIGN_ID" "$(cut -d' ' -f1-2 "$KEY.pub")" \
              > "$STORE/signers/$HOST.pub"
          fi

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

            local h; h="$(sha256sum "$f" | cut -d' ' -f1)"
            # content-hash dedup: skip if the newest snapshot is byte-identical.
            # epoch-prefixed names sort chronologically, so the last glob match is newest.
            local last="" c
            for c in "$dir"/*.md; do [[ -e "$c" ]] && last="$c"; done
            if [[ -n "$last" ]]; then
              [[ "$(sha256sum "$last" | cut -d' ' -f1)" == "$h" ]] && return 0
            fi

            local base; base="$dir/$(date +%s).$HOST.md"
            cp "$f" "$base"
            ssh-keygen -Y sign -f "$KEY" -n file "$base" >/dev/null 2>&1 || true
            printf 'captured %s\n' "$base"
          }

          exec inotifywait -m -r -e close_write --format '%w%f' \
            --exclude '(/\.git/|/\.obsidian/|/\.trash/|/\.provenance/)' "$VAULT" |
          while read -r path; do snapshot "$path" || true; done
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
          [[ -d "$STORE" ]] || exit 0

          # 1) stamp any snapshot (and optionally its .sig) that has no .ots yet
          find "$STORE" -type f -name '*.md' -print0 | while IFS= read -r -d "" f; do
            [[ -e "$f.ots" ]] || ots stamp "$f" || true
            if [[ "$STAMP_SIG" = 1 && -e "$f.sig" ]]; then
              [[ -e "$f.sig.ots" ]] || ots stamp "$f.sig" || true
            fi
          done

          # 2) upgrade all pending .ots (no-op once confirmed; needs network)
          find "$STORE" -type f -name '*.ots' -print0 \
            | xargs -0 -r -n1 ots upgrade >/dev/null 2>&1 || true

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

      env = [
        "GRIMOIRE_VAULT=${vault}"
        "GRIMOIRE_SIGN_KEY=${signKey}"
        "GRIMOIRE_SIGN_ID=${signId}"
      ];
    in {
      home-manager.users.xin = { lib, ... }: {
        home.packages = [ capture reconcile verify package ];

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
            Environment = env;
          };
          Install.WantedBy = [ "default.target" ];
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
