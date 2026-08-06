{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, config, ... }:
    let
      cfait = pkgs.callPackage (import ./Cfait/_cfait.nix) { };
    in {
      environment.systemPackages = with pkgs; [
        obsidian
        taskwarrior3
        taskwarrior-tui
        timewarrior
        cfait

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
