{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      obsidian
      taskwarrior3
      timewarrior

      (pkgs.makeDesktopItem {
        name = "pomofocus";
        desktopName = "Pomofocus";
        exec = "${pkgs.brave}/bin/brave --app=https://pomofocus.io --start-maximized";
        icon = "${pkgs.fetchurl { name = "timer.svg"; url = "https://api.iconify.design/mdi:timer.svg"; sha256 = "sha256-TMBdlXz0OmiiFTaKJkeLpPeAsnFbqP1AGN4wiufqoVk="; }}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };
}
