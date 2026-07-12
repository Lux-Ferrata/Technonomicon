{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, config, ... }:
    let
      task2habitica = pkgs.callPackage (import ./Habitica/_task2habitica.nix) { };

      habiticaEnvExport = ''
        export HABITICA_USER_ID="$(cat ${config.sops.secrets.habitica-user-id.path})"
        export HABITICA_API_KEY="$(cat ${config.sops.secrets.habitica-api-token.path})"
      '';
    in {
      environment.systemPackages = with pkgs; [
        obsidian
        taskwarrior3
        taskwarrior-tui
        timewarrior
        task2habitica

        pomodoro-gtk
      ];

      sops.secrets.habitica-user-id.owner = "xin";
      sops.secrets.habitica-api-token.owner = "xin";

      xdg.mime.defaultApplications = {
        "x-scheme-handler/obsidian" = "obsidian.desktop";
      };

      home-manager.users.xin = {
        programs.taskwarrior = {
          enable = true;
          package = pkgs.taskwarrior3;
          config = {
            uda.habitica_uuid = {
              label = "Habitica UUID";
              type = "string";
            };
            uda.habitica_difficulty = {
              label = "Habitica Difficulty";
              type = "string";
              values = [ "trivial" "easy" "medium" "hard" ];
            };
            uda.habitica_task_type = {
              label = "Habitica Task Type";
              type = "string";
              values = [ "daily" "todo" ];
            };
          };
        };

        home.file.".local/share/task/hooks/on-add.task2habitica" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            ${habiticaEnvExport}
            if command -v task2habitica >/dev/null; then
                task2habitica add
            else
                read -r new_task
                echo "$new_task"
                echo "task2habitica is not installed. Taskwarrior is not syncing with Habitica." >&2
                exit 0
            fi
          '';
        };

        home.file.".local/share/task/hooks/on-modify.task2habitica" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            ${habiticaEnvExport}
            if command -v task2habitica >/dev/null; then
                task2habitica modify
            else
                read -r _
                read -r new_task
                echo "$new_task"
                echo "task2habitica is not installed. Taskwarrior is not syncing with Habitica." >&2
                exit 0
            fi
          '';
        };

        home.file.".local/share/task/hooks/on-exit.task2habitica" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            ${habiticaEnvExport}
            if command -v task2habitica >/dev/null; then
                output="$(task2habitica exit)"
                echo "$output"
                while IFS= read -r line; do
                    case "$line" in
                        "LEVEL UP!"*)
                            ${pkgs.libnotify}/bin/notify-send -i trophy-gold "Habitica: Level Up!" "$line"
                            ;;
                        "LEVEL LOST!"*)
                            ${pkgs.libnotify}/bin/notify-send -i dialog-warning "Habitica: Level Lost" "$line"
                            ;;
                        HP:* | MP:* | Exp:* | Gold:* | "")
                            ;;
                        *)
                            ${pkgs.libnotify}/bin/notify-send -i emblem-favorite "Habitica: Item Found" "$line"
                            ;;
                    esac
                done <<< "$output"
            else
                echo "task2habitica is not installed. Taskwarrior is not syncing with Habitica." >&2
                exit 0
            fi
          '';
        };
      };
    };
}
