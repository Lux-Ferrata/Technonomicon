{ inputs, ... }: {
  # Kvasir's side of "Akmon is the dev box": every way of starting work
  # (editor, terminal, one-off command) lands on Akmon when the tailnet can
  # reach it and quietly stays local when it can't. Server side: Tn-dev-host.
  flake.nixosModules.Tn-dev-client = { lib, pkgs, ... }:
  let
    sync = import ./_sync.nix;

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
  in {

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

    home-manager.users.xin = {
      home.packages = [ akmonReady ];

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
        # Run one command on Akmon in the same directory (with the project's
        # direnv env) when it can be, locally otherwise. Output and build
        # artifacts stay wherever it ran.
        rb = ''
          test (count $argv) -gt 0; or begin; echo "usage: rb <command...>"; return 1; end
          if akmon-ready $PWD
            ssh -t akmon "cd "(string escape -- $PWD)" && direnv exec . "(string join " " -- (string escape -- $argv))
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
