{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, ... }: {

    environment.systemPackages = [

      (pkgs.makeDesktopItem {
        name = "Discord-App";
        desktopName = "Discord App";
        exec = "${pkgs.brave}/bin/brave --app=https://www.discord.gg/channels/@me --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "khan-academy";
        desktopName = "Khan Academy";
        exec = "${pkgs.brave}/bin/brave --app=https://www.khanacademy.org --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "the-odin-project";
        desktopName = "TOP: The Odin Project";
        exec = "${pkgs.brave}/bin/brave --app=https://www.theodinproject.com/dashboard --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "youtube";
        desktopName = "YouTube";
        exec = "${pkgs.brave}/bin/brave --app=https://www.youtube.com --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "gemini";
        desktopName = "Gemini";
        exec = "${pkgs.brave}/bin/brave --app=https://gemini.google.com/app --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "steno-jig";
        desktopName = "Steno Jig";
        exec = "${pkgs.brave}/bin/brave --app=https://joshuagrams.github.io/steno-jig/form.html --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "typey-type";
        desktopName = "Typey Type";
        exec = "${pkgs.brave}/bin/brave --app=https://didoesdigital.com/typey-type/lessons/ --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Mail";
        desktopName = "Gmail Email";
        exec = "${pkgs.brave}/bin/brave --app=https://gmail.com --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Calendar";
        desktopName = "Calendar";
        exec = "${pkgs.brave}/bin/brave --app=https://calendar.google.com --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Toggl";
        desktopName = "Toggl Time Tracking";
        exec = "${pkgs.brave}/bin/brave --app=https://track.toggl.com/timer --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "syncthing";
        desktopName = "Syncthing";
        exec = "${pkgs.brave}/bin/brave --app=http://localhost:8385/ --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Exercism";
        desktopName = "Exercism";
        exec = "${pkgs.brave}/bin/brave --app=https://exercism.org/dashboard --start-maximized";
        terminal = false;
        categories = [ "Application" "Network" ];
      })
    ];
  };
}
