{ inputs, ... }: {
  # Grimoire (the Obsidian vault) on Akmon: Syncthing keeps the files in step
  # with Kvasir and the phone (_sync.nix); this module owns its git history.
  # Every 5 minutes, once the vault has settled, the changes are committed
  # and pushed to Forgejo (xin/Grimoire, push-mirrored to GitHub). .git
  # exists only here -- Kvasir runs `grimoire-commit "msg"` for a named one.
  flake.nixosModules.Tn-grimoire = { config, lib, pkgs, ... }:
  let
    vault  = "/srv/xin/Grimoire";
    stApi  = "http://${config.services.syncthing.guiAddress}/rest";
    remote = "http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}/xin/Grimoire.git";

    snapshot = pkgs.writeShellApplication {
      name = "grimoire-snapshot";
      runtimeInputs = with pkgs; [ git openssh coreutils findutils gnugrep curl jq ];
      text = ''
        # grimoire-snapshot            commit if the vault has settled
        # grimoire-snapshot -m MSG     commit now, with MSG
        msg=""
        if [ "''${1:-}" = -m ]; then msg=''${2:?usage: grimoire-snapshot [-m MSG]}; fi

        cd ${vault}
        [ -d .git ] || { echo "grimoire-snapshot: ${vault} has no .git yet" >&2; exit 0; }

        if [ -z "$msg" ]; then
          # never commit a half-arrived edit: Syncthing must be idle ...
          key=$(grep -oP '(?<=<apikey>)[^<]+' ${config.services.syncthing.configDir}/config.xml) || exit 0
          state=$(curl -sf -H "X-API-Key: $key" "${stApi}/db/status?folder=grimoire" | jq -r .state) || exit 0
          [ "$state" = idle ] || exit 0
          # ... and nothing may have changed in the last minute
          recent=$(find . -path ./.git -prune -o -newermt "@$(( $(date +%s) - 60 ))" -print -quit)
          [ -z "$recent" ] || exit 0
        fi

        git add -A
        if ! git diff --cached --quiet; then
          if [ -z "$msg" ]; then
            n=$(git diff --cached --name-only | wc -l)
            some=$(git diff --cached --name-only | head -3 | paste -sd, -)
            [ "$n" -gt 3 ] && some="$some, ..."
            msg="auto: $n file$([ "$n" = 1 ] || echo s) -- $some"
          fi
          git commit -q -m "$msg"
        elif [ "''${1:-}" = -m ]; then
          echo "grimoire-snapshot: nothing to commit"
        fi

        # push whatever isn't on Forgejo yet (also retries an earlier failed push)
        tok=$(cat ${config.sops.secrets.forgejo-agent-token.path})
        git -c "http.extraHeader=Authorization: token $tok" push -q ${remote} HEAD:main \
          || echo "grimoire-snapshot: push failed, will retry next run" >&2
      '';
    };
  in {
    environment.systemPackages = [ snapshot ];

    sops.secrets.forgejo-agent-token = { owner = "xin"; mode = "0400"; };

    # as xin (the vault's files are xin's); xin lingers, so it runs unattended
    home-manager.users.xin.systemd.user = {
      services.grimoire-snapshot = {
        Unit.Description = "Commit and push Grimoire changes";
        Service = {
          Type      = "oneshot";
          ExecStart = "${snapshot}/bin/grimoire-snapshot";
          Nice      = 10;
        };
      };
      timers.grimoire-snapshot = {
        Unit.Description = "Grimoire git snapshot every 5 minutes";
        Timer = {
          OnCalendar = "*:0/5";
          Persistent = false;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
