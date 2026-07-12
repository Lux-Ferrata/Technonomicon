{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      obsidian
      taskwarrior3
      taskwarrior-tui
      timewarrior

      pomodoro-gtk
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };

    home-manager.users.xin = {
      programs.taskwarrior = {
        enable = true;
        package = pkgs.taskwarrior3;
      };
    };
  };
}
