{ inputs, ... }: {
  # Kvasir's side of "Akmon is the dev box": every way of starting work
  # (editor, terminal, one-off command) lands on Akmon when the tailnet can
  # reach it and quietly stays local when it can't. Server side: Tn-dev-host.
  flake.nixosModules.Tn-dev-client = { ... }:
  let
    sync = import ./_dev-sync.nix;
  in {

    # ~/Projects <-> Akmon. Everything else here is still GUI-managed
    # (Grimoire, Media, ...), so declaring one folder must not delete the rest.
    services.syncthing = {
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        devices.Akmon = {
          id        = sync.akmonId;
          addresses = [ "tcp://akmon:22000" ];
        };
        folders.${sync.folderId} = {
          label           = "Projects";
          path            = "/home/xin/Projects";
          devices         = [ "Akmon" ];
          type            = "sendreceive";
          # switching machines right after saving shouldn't lose the edit
          fsWatcherDelayS = 1;
          inherit (sync) ignorePatterns;
        };
      };
    };

    home-manager.users.xin = {
      programs.ssh = {
        enable              = true;
        enableDefaultConfig = false;
        matchBlocks.akmon = {
          # one TCP connection shared by ak / rb / eo / Remote-SSH: later
          # connects are instant and the reachability probe is nearly free
          controlMaster  = "auto";
          controlPath    = "~/.ssh/cm-%C";
          controlPersist = "10m";
          # tailscale keeps akmon's address across wifi changes, so a TCP
          # session can ride out ~2 minutes of no network before giving up
          serverAliveInterval    = 15;
          serverAliveCountMax    = 8;
          # push to Forgejo/GitHub from shells and editor windows on Akmon
          forwardAgent = true;
        };
      };

      programs.fish.functions = {
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
