{ inputs, ... }: {
  # Overnight agents on Akmon: Claude supervises the local models through a
  # queue of Forgejo issues (agents/overnight.sh, agents/lagent.sh). Runs as
  # xin every night, or on demand (`systemctl --user start overnight`, or
  # `overnight-now` from Kvasir). Night mode hands the whole GPU to the chat
  # model while nobody needs code completion.
  flake.nixosModules.Tn-overnight = { config, lib, pkgs, pkgs-stable, ... }:
  let
    lagent = pkgs.writeShellApplication {
      name          = "lagent";
      runtimeInputs = with pkgs; [ curl jq git coreutils gnused systemd pkgs-stable.aider-chat ];
      text          = builtins.readFile ../../agents/lagent.sh;
    };
    overnight = pkgs.writeShellApplication {
      name          = "overnight";
      runtimeInputs = with pkgs; [ curl jq git coreutils gnugrep gnused claude-code lagent ];
      # carries on past a failed task instead of dying (it reports instead)
      bashOptions   = [ "nounset" "pipefail" ];
      text          = builtins.readFile ../../agents/overnight.sh;
    };
  in {
    environment.systemPackages = [ lagent overnight ];

    # Claude's subscription token and the mail relay, as the CI runner has
    users.users.xin.extraGroups = [ "ci-secrets" "mail-senders" ];
    # issues, comments, PRs, research notes in xin/agent-tasks
    sops.secrets.forgejo-agent-token = { owner = "xin"; mode = "0400"; };

    # task clones + logs; a fortnight is plenty to read a report
    systemd.tmpfiles.rules = [ "d /srv/xin/agent-work 0750 xin users 14d" ];

    home-manager.users.xin.systemd.user = {
      services.overnight = {
        Unit.Description = "Overnight agent run (Claude + local models)";
        Service = {
          Type = "oneshot";
          # tasks build and test things: the same tools as an interactive shell
          Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/xin/bin:/run/current-system/sw/bin";
          ExecStart   = "${overnight}/bin/overnight";
          Nice        = 5;
          TimeoutStartSec = "7h";
        };
      };
      timers.overnight = {
        Unit.Description = "Nightly overnight agent run";
        Timer.OnCalendar = "*-*-* 00:10:00";
        Install.WantedBy = [ "timers.target" ];
      };
    };

    # ── Night mode: 00:00-05:45 the chat model gets the whole GPU ────────
    # Stopping completion (and its socket, so nothing wakes it) frees ~13 GB
    # of VRAM; the chat server is stopped too so its next wake-up --fits
    # into all of it. In the morning completion goes back to on-request.
    systemd.services.llama-night = {
      description = "Night mode: GPU to the chat model";
      serviceConfig.Type = "oneshot";
      script = "systemctl stop llama-fim.socket llama-fim.service llama-fim-server.service llama-chat-server.service";
    };
    systemd.timers.llama-night = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*-*-* 00:00:00";
    };
    systemd.services.llama-day = {
      description = "Day mode: GPU back to code completion";
      serviceConfig.Type = "oneshot";
      script = ''
        systemctl stop llama-chat-server.service
        systemctl start llama-fim.socket
      '';
    };
    systemd.timers.llama-day = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*-*-* 05:45:00";
    };
  };
}
