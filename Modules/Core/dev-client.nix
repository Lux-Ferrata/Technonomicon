{ inputs, ... }: {
  # Kvasir's side of "Akmon is the dev box": every way of starting work
  # (editor, terminal, one-off command) lands on Akmon when the tailnet can
  # reach it and quietly stays local when it can't. Server side: Tn-dev-host.
  flake.nixosModules.Tn-dev-client = { config, lib, pkgs, ... }:
  let
    sync   = import ./_sync.nix;
    models = pkgs.callPackage ./_models.nix { };
    # tailnet IP, not the name: nginx resolves upstreams once at start, and
    # at boot MagicDNS may not be up yet
    akmonIp = "100.122.244.58";

    # Exit 0 when <path> (default .) should be worked on on Akmon: it's a
    # synced project, Akmon answers within 2s, and Akmon has every change
    # this machine has made there (waits up to ~10s for that). Used by `eo`
    # (VS Code) and `rb`; the ssh probe rides the shared ControlMaster.
    akmonReady = pkgs.writeShellScriptBin "akmon-ready" ''
      p=$(realpath -m -- "''${1:-.}")
      case "$p" in
        "$HOME/Projects/Technonomicon"|"$HOME/Projects/Technonomicon/"*) exit 1 ;;
        "$HOME/Projects/"*) ;;
        *) exit 1 ;;
      esac
      ssh -o BatchMode=yes -o ConnectTimeout=2 akmon true 2>/dev/null || exit 1

      key=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml) || exit 0
      api=http://127.0.0.1:8385/rest
      # pick up the last save now instead of after the watcher delay
      ${pkgs.curl}/bin/curl -sf -X POST -H "X-API-Key: $key" "$api/db/scan?folder=${"projects"}" >/dev/null
      for _ in $(seq 20); do
        c=$(${pkgs.curl}/bin/curl -sf -H "X-API-Key: $key" \
              "$api/db/completion?folder=projects&device=${sync.devices.Akmon}" \
            | ${pkgs.jq}/bin/jq -r .completion)
        [ "$c" = 100 ] && exit 0
        sleep 0.5
      done
      echo "akmon-ready: Akmon hasn't caught up on ~/Projects yet; going ahead anyway" >&2
    '';
    # Grimoire's git history lives on Akmon (Tn-grimoire), which also takes
    # the named commits; the message travels on stdin, not through fish
    # Both first wait (up to ~10 s) for Syncthing to hand Akmon the latest edits.
    grimoireCmds = pkgs.writeShellApplication {
      name = "grimoire-commit";
      runtimeInputs = with pkgs; [ curl jq gnugrep openssh coreutils ];
      text = ''
        synced() {
          key=$(grep -oP '(?<=<apikey>)[^<]+' ~/.config/syncthing/config.xml) || return 0
          api=http://127.0.0.1:8385/rest
          curl -sf -X POST -H "X-API-Key: $key" "$api/db/scan?folder=grimoire" >/dev/null || return 0
          for _ in $(seq 20); do
            c=$(curl -sf -H "X-API-Key: $key" \
                  "$api/db/completion?folder=grimoire&device=${sync.devices.Akmon}" | jq -r .completion)
            [ "$c" = 100 ] && return 0
            sleep 0.5
          done
          echo "grimoire: Akmon hasn't caught up yet; going ahead anyway" >&2
        }
        synced
        case "$(basename "$0")" in
          grimoire-git)
            # the args travel NUL-separated on stdin: no quoting through fish
            printf '%s\0' "$@" | ssh akmon grimoire-git --stdin-args ;;
          *)
            [ $# -gt 0 ] || { echo "usage: grimoire-commit MESSAGE" >&2; exit 1; }
            printf '%s' "$*" | ssh akmon grimoire-snapshot -m - ;;
        esac
      '';
    };
    grimoireGit = pkgs.runCommand "grimoire-git" { } ''
      mkdir -p $out/bin && ln -s ${grimoireCmds}/bin/grimoire-commit $out/bin/grimoire-git
    '';
    # deploy <akmon|kvasir|all> [nh args]: Akmon is evaluated here, built and
    # switched there; Kvasir is built on Akmon too when it's reachable (the
    # whole closure, not just what distributed builds would hand over) and
    # switched locally; offline it builds here.
    # The password is asked once, before anything builds (both hosts share
    # xin-password). nh only takes a remote sudo password from its own
    # prompt (at the end), so Akmon is done by hand: evaluate, build on
    # Akmon, switch over ssh with the password on sudo's stdin (as nh
    # does). Kvasir gets it through nh's local askpass hook. nh args only
    # go to Kvasir.
    askpass = pkgs.writeShellScript "deploy-askpass" ''printf '%s\n' "$TN_DEPLOY_PW"'';
    deploy = pkgs.writeShellApplication {
      name = "deploy";
      # store paths in ssh commands are meant to expand here, on Kvasir
      excludeShellChecks = [ "SC2029" ];
      # the system nh (NH_FLAKE points it at this repo) and sudo wrapper
      text = ''
        flake=''${NH_OS_FLAKE:-''${NH_FLAKE:-$HOME/Projects/Technonomicon}}
        flake=''${flake%/}
        step() { printf '\e[1;36m› %s\e[0m\n' "$*"; }

        kvasir() {
          if ssh -o BatchMode=yes -o ConnectTimeout=3 xin@akmon true 2>/dev/null; then
            nh os switch --hostname Kvasir --build-host xin@akmon "$@"
          else
            step "Akmon unreachable: building Kvasir locally"
            nh os switch --hostname Kvasir "$@"
          fi
        }

        akmon_with_pw() {
          local drv out
          step "Akmon: evaluating"
          drv=$(nix eval --raw "$flake#nixosConfigurations.Akmon.config.system.build.toplevel.drvPath")
          step "Akmon: building on akmon"
          nix copy --derivation --to ssh-ng://xin@akmon "$drv"
          out=$(ssh xin@akmon "nix build --no-link --print-out-paths -L '$drv^out'")
          if [ "$(ssh xin@akmon readlink -f /run/current-system)" = "$out" ]; then
            step "Akmon: already running this generation"; return 0
          fi
          ssh xin@akmon "nix store diff-closures /run/current-system $out"
          step "Akmon: switching"
          # systemd-run: the switch finishes even if it restarts sshd or
          # tailscale and the connection drops
          printf '%s\n' "$TN_DEPLOY_PW" | ssh -T xin@akmon \
            "sudo -S -p ''' sh -c 'nix-env -p /nix/var/nix/profiles/system --set $out && systemd-run -E LOCALE_ARCHIVE --collect --no-ask-password --pipe --quiet --service-type=exec --unit=deploy-switch-to-configuration $out/bin/switch-to-configuration switch'"
        }

        target=$(printf '%s' "''${1:-}" | tr '[:upper:]' '[:lower:]')
        [ $# -gt 0 ] && shift
        case "$target" in
          akmon|kvasir|all) ;;
          *) echo "usage: deploy <akmon|kvasir|all> [nh os switch args (Kvasir only)...]" >&2; exit 2 ;;
        esac
        if [ "$target" = akmon ] && [ $# -gt 0 ]; then
          echo "deploy: nh args only apply to Kvasir; ignoring: $*" >&2
        fi

        # the password up front, so a long build doesn't end at a prompt
        read -rsp "[sudo] password for $USER: " pw; echo
        # check it (and prime this terminal's sudo) before any build starts
        printf '%s\n' "$pw" | /run/wrappers/bin/sudo -S -k -p "" -v 2>/dev/null \
          || { echo "deploy: wrong password" >&2; exit 1; }
        export TN_DEPLOY_PW=$pw NH_SUDO_ASKPASS=${askpass} SUDO_ASKPASS=${askpass}
        unset pw

        case "$target" in
          akmon)  akmon_with_pw ;;
          kvasir) kvasir "$@" ;;
          all)
            # the server first: Kvasir's builds go through it
            if akmon_with_pw; then a="✓"; else a="✗"; fi
            if [ "$a" = "✓" ]; then
              if kvasir "$@"; then k="✓"; else k="✗"; fi
            else
              k="– (skipped)"
            fi
            unset TN_DEPLOY_PW
            printf '\nAkmon %s   Kvasir %s\n' "$a" "$k"
            [ "$a$k" = "✓✓" ]
            ;;
        esac
      '';
    };
  in {
    # Chat stand-in for when Akmon is away: started by the first offline
    # chat request, stopped again after 10 idle minutes, so it costs no RAM
    # the rest of the time.
    imports = [
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "llama-chat-fallback";
        description = "Offline chat model (Qwen2.5-Coder-3B-Instruct, CPU)";
        port        = 8014;
        backendPort = 8015;
        idle        = "10min";
        args = [
          "${config.services.llama-cpp.package}/bin/llama-server"
          "--model ${models.chat-3b}"
          "--alias chat"
          "--jinja --ctx-size 16384 --threads 4"
        ];
        extra = { Nice = 10; CPUWeight = 20; };
      })

      # Speech-to-text stand-in (whisper.cpp base, CPU) for `stt` while
      # Akmon is away; same wake-on-request pattern.
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "whisper-fallback";
        description = "Offline speech-to-text (whisper.cpp base, CPU)";
        port        = 8021;
        backendPort = 8022;
        idle        = "10min";
        healthPath  = "/";
        args = [
          "${pkgs.whisper-cpp}/bin/whisper-server"
          "--model ${models.whisper-base}"
          "--language auto --convert --threads 4"
        ];
        extra = { Nice = 10; CPUWeight = 20; };
      })
    ];
    systemd.services.whisper-fallback-server.path = [ pkgs.ffmpeg-headless ];


    # Declarative now: folders/devices not in _sync.nix get dropped from
    # Syncthing (their files stay put). Everything goes through Akmon.
    services.syncthing.settings = {
      devices = {
        Akmon = { id = sync.devices.Akmon; addresses = [ "tcp://akmon:22000" ]; };
        Phone = { id = sync.devices.Phone; };
      };
      folders = lib.mapAttrs (id: f: {
        inherit id;
        inherit (f) label;
        path            = f.kvasir;
        devices         = [ "Akmon" ];
        type            = if f.mode == "backup" then "sendonly" else "sendreceive";
        # switching machines right after saving shouldn't lose the edit
        fsWatcherDelayS = 1;
        ignorePatterns  = f.ignorePatterns or null;
      }) sync.folders;
    };

    # ── Local LLM endpoints: Akmon's GPU when reachable, this CPU if not ──
    # The editor and aider only ever talk to 127.0.0.1 -- 8012 completion
    # (FIM), 8011 chat, 8020 speech-to-text -- and nginx sends each to Akmon (Tn-dev-host) or,
    # when that can't be reached, to the local stand-in. No setting ever
    # changes between online and offline.
    services.nginx = {
      enable = true;
      appendHttpConfig = let
        route = name: port: backup: ''
          upstream llm_${name} {
            server ${akmonIp}:${toString port} max_fails=1 fail_timeout=30s;
            server 127.0.0.1:${toString backup} backup;
          }
          server {
            listen 127.0.0.1:${toString port};
            location / {
              proxy_pass            http://llm_${name};
              proxy_connect_timeout 1s;
              proxy_next_upstream   error timeout;
              proxy_buffering       off;     # streamed tokens
              proxy_read_timeout    600s;
            }
          }
        '';
      in route "fim" 8012 8013 + route "chat" 8011 8014 + route "stt" 8020 8021;
    };

    # FIM stand-in: small, always up (completion has to be instant)
    services.llama-cpp = {
      enable   = true;
      settings = {
        port        = 8013;
        model       = models.fim-1_5b;
        threads     = 4;                   # leave half the CPU to the user
        ctx-size    = 8192;
        batch-size  = 1024;
        ubatch-size = 512;
        cache-reuse = 256;
      };
    };
    # it only matters when Akmon is away; never compete with the desktop
    systemd.services.llama-cpp.serviceConfig = {
      Nice           = 10;
      CPUWeight      = 20;
      # a missing/broken fallback shouldn't wait 5 min to come back
      RestartSec     = lib.mkForce 10;
    };

    home-manager.users.xin = {
      home.packages = [ akmonReady deploy grimoireCmds grimoireGit
        (pkgs.callPackage ./_stt.nix { })   # speech to text, Akmon's GPU or local CPU
        (pkgs.callPackage ./_tts.nix { })   # text to speech, local (Kokoro)
      ];
      xdg.configFile."fish/completions/deploy.fish".text = ''
        complete -c deploy -f -n __fish_use_subcommand -a akmon  -d "build + switch on Akmon"
        complete -c deploy -f -n __fish_use_subcommand -a kvasir -d "switch this laptop"
        complete -c deploy -f -n __fish_use_subcommand -a all    -d "Akmon, then Kvasir; one password"
      '';

      # Offline readiness: while Akmon is reachable (its binary cache and
      # builders do the work), realise every project's dev environment here
      # so `direnv`/`nix develop` work instantly with no network. nix-direnv
      # roots what it builds under each project's .direnv; flakes without an
      # .envrc get a profile root under ~/.cache/devshells.
      systemd.user.services.prewarm-devshells = {
        Unit.Description = "Pre-build ~/Projects dev shells for offline use";
        Service = {
          Type     = "oneshot";
          Nice     = 19;
          IOSchedulingClass = "idle";
          Environment = [
            "DIRENV_CONFIG=/etc/direnv"
            "PATH=${lib.makeBinPath [ pkgs.nix pkgs.direnv pkgs.git pkgs.bash pkgs.coreutils pkgs.curl pkgs.gnugrep ]}"
          ];
          ExecStart = pkgs.writeShellScript "prewarm-devshells" ''
            # only while the cache/builders are there: otherwise this would
            # build everything on the laptop
            curl -sf -m 5 http://${akmonIp}:5000/nix-cache-info >/dev/null || {
              echo "Akmon unreachable; skipping"; exit 0; }
            roots=$HOME/.cache/devshells; mkdir -p "$roots"
            for d in "$HOME"/Projects/*/; do
              name=$(basename "$d")
              [ "$name" = Technonomicon ] && continue
              if [ -f "$d/.envrc" ]; then
                echo "== $name (direnv)"
                direnv exec "$d" true || echo "   failed (not allowed, or the shell doesn't build)"
              elif [ -f "$d/flake.nix" ] && nix flake show "$d" --json 2>/dev/null | grep -q '"devShells"'; then
                echo "== $name (flake)"
                nix develop "$d" --profile "$roots/$name" -c true || echo "   failed"
              fi
            done
          '';
        };
      };
      systemd.user.timers.prewarm-devshells = {
        Unit.Description = "Pre-build ~/Projects dev shells for offline use";
        Timer = {
          OnBootSec        = "15min";
          OnUnitActiveSec  = "3h";
          Persistent       = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      programs.ssh = {
        enable              = true;
        enableDefaultConfig = false;
        settings.akmon = {
          # one TCP connection shared by ak / rb / eo / Remote-SSH: later
          # connects are instant and the reachability probe is nearly free
          ControlMaster  = "auto";
          ControlPath    = "~/.ssh/cm-%C";
          ControlPersist = "10m";
          # tailscale keeps akmon's address across wifi changes, so a TCP
          # session can ride out ~2 minutes of no network before giving up
          ServerAliveInterval = 15;
          ServerAliveCountMax = 8;
          # push to Forgejo/GitHub from shells and editor windows on Akmon
          ForwardAgent = true;
        };
      };

      programs.fish.functions = {
        # Queue a task for the overnight agents (Akmon, Tn-overnight):
        #   overnight-add "Write tests for parser.py" [project|owner/repo] [details...]
        # A name with a slash is a Forgejo repo (result: PR), a bare name a
        # git project in ~/Projects (result: branch), none a research task.
        overnight-add = ''
          test (count $argv) -ge 1; or begin
            echo "usage: overnight-add TITLE [PROJECT|OWNER/REPO] [DETAILS...]"; return 1
          end
          set -l body ""
          if test (count $argv) -ge 2; and test -n "$argv[2]"
            if string match -q "*/*" -- $argv[2]
              set body "repo: $argv[2]"
            else
              set body "project: $argv[2]"
            end
          end
          test (count $argv) -ge 3; and set body "$body"\n\n(string join " " -- $argv[3..])
          set -l api https://git.ironshark.org/api/v1/repos/xin/agent-tasks
          set -l tok (cat ~/.config/forgejo-token)
          set -l label (curl -sf -H "Authorization: token $tok" "$api/labels" | jq '.[] | select(.name=="overnight") | .id')
          jq -n --arg t "$argv[1]" --arg b (printf "%b" "$body") --argjson l "[$label]" '{title:$t, body:$b, labels:$l}' \
            | curl -sf -X POST -H "Authorization: token $tok" -H "Content-Type: application/json" -d @- "$api/issues" \
            | jq -r '"queued #\(.number): \(.html_url)"'
        '';
        # Akmon's load (Tn-server-usage): btop live, `aku -s` one-screen
        # snapshot with pools + llama servers, `aku --week` the 7-day digest
        aku = "ssh -t akmon aku $argv";

        # start a run now instead of waiting for 00:10
        overnight-now = "ssh akmon systemctl --user start --no-block overnight; and echo 'started; follow with: ssh akmon journalctl --user -fu overnight'";

        # Run one command on Akmon in the same directory (with the project's
        # direnv env) when it can be, locally otherwise. Output and build
        # artifacts stay wherever it ran.
        rb = ''
          test (count $argv) -gt 0; or begin; echo "usage: rb <command...>"; return 1; end
          if akmon-ready $PWD
            # a terminal only when there is one (interactive tools, colours)
            set -l tty; isatty stdin; and set tty -t
            ssh $tty akmon "cd "(string escape -- $PWD)" && direnv exec . "(string join " " -- (string escape -- $argv))
          else
            $argv
          end
        '';

        # Shell on Akmon that survives disconnects and laptop reboots (shpool
        # keeps it alive there). Inside ~/Projects/<p> the session is named
        # after the project and starts in the same path -- the paths are
        # identical on both machines -- otherwise it's "main" in ~.
        # Technonomicon isn't synced to Akmon, so it counts as "otherwise".
        # Reconnects by itself whenever the connection drops (ssh exit 255).
        ak = ''
          set -l name $argv[1]
          set -l dir $HOME
          set -l rel (string replace -- "$HOME/Projects/" "" $PWD)
          if test "$rel" != "$PWD"; and not string match -q -- "Technonomicon*" $rel
            set dir $PWD
            test -z "$name"; and set name (string split -m1 / -- $rel)[1]
          end
          test -z "$name"; and set name main
          while true
            ssh -t akmon shpool attach -f -d (string escape -- $dir) -- (string escape -- $name)
            set -l rc $status
            test $rc -eq 255; or return $rc
            echo "ak: connection to akmon lost, retrying..." >&2
            sleep 2
          end
        '';
      };
    };
  };
}
