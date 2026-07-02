{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, ... }:
    let
      icon = url: sha256: pkgs.fetchurl { inherit url sha256; };
      icons = {
        khanAcademy  = icon "https://api.iconify.design/simple-icons:khanacademy.svg"  "0dj7ii2xc256fl71wl4qyhd8xypslqj4fy8dmnns4ah1cp5djskv";
        odinProject  = icon "https://api.iconify.design/simple-icons:theodinproject.svg" "1d97z6pxfvkdr456l3bggs5i86j93j94dr71jnvqy1ns7brx98k1";
        youtube      = icon "https://api.iconify.design/logos:youtube-icon.svg"          "1b2ifnm4g640zhgqjxaf97f3ki2jsqn66vzgc0392014w88c52in";
        gemini       = icon "https://api.iconify.design/logos:google-gemini.svg"         "007mc0924pylwkfgazxn1vxxzdq0xpmqxz6z8hs25db94as0n150";
        stenoJig     = icon "https://api.iconify.design/tabler:keyboard.svg"             "1yv2yq138qp0jh73amny4rbxxpxkdcb4c93k9zd0xwcvh87l2kph";
        typeyType    = icon "https://didoesdigital.com/typey-type/favicon-192x192.png"   "0736jdsqnj0pj8m1gpqpqrhwgbf8diz6zwn2qp8xcd7rm8f3s54j";
        gmail        = pkgs.fetchurl { name = "gmail.svg"; sha256 = "01gvhxl2wxjmfj5fhdmr3l12ydlmkiqna5snpgk1nd4wjgzrs4ny"; url = "https://upload.wikimedia.org/wikipedia/commons/7/7e/Gmail_icon_%282020%29.svg"; };
        calendar     = icon "https://api.iconify.design/logos:google-calendar.svg"       "1v7gabrwk95bq391my3ish5p4qi38pxwfiwl4yaxcyx97kgrrd5b";
        toggl        = icon "https://api.iconify.design/simple-icons:toggl.svg"          "1rny5vlximfk4xm5bkcrh617i29nbg82x3zifz3c2vcsmlclkssh";
        syncthing    = icon "https://api.iconify.design/simple-icons:syncthing.svg"      "0kb6gjsi674gcq2y757ahgycfn0zmgzq6928nwl6ps2mfjgk0pn5";
        exercism     = icon "https://api.iconify.design/simple-icons:exercism.svg"       "00md3wqkcy2yi0i4k98kxalxf6h32pxmgqqr6phb5yzcg5b2wywb";
        bitwarden    = icon "https://api.iconify.design/simple-icons:bitwarden.svg"      "0gxhn0700vszcg9v68nzf0j1f321zpimzp68blf5pnw983ljr8y6";
        habitica     = icon "https://api.iconify.design/game-icons:dragon-head.svg"     "0vkc7m6hdl6c5kvzwygvl0rpk4nw80zsgw2zyjk4m107gm2n0n21";
      };
    in {

    environment.systemPackages = [

      (pkgs.makeDesktopItem {
        name = "khan-academy";
        desktopName = "Khan Academy";
        exec = "${pkgs.brave}/bin/brave --app=https://www.khanacademy.org --start-maximized";
        icon = "${icons.khanAcademy}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "the-odin-project";
        desktopName = "TOP: The Odin Project";
        exec = "${pkgs.brave}/bin/brave --app=https://www.theodinproject.com/dashboard --start-maximized";
        icon = "${icons.odinProject}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "youtube";
        desktopName = "YouTube";
        exec = "${pkgs.brave}/bin/brave --app=https://www.youtube.com/feed/subscriptions --start-maximized";
        icon = "${icons.youtube}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "gemini";
        desktopName = "Gemini";
        exec = "${pkgs.brave}/bin/brave --app=https://gemini.google.com/app --start-maximized";
        icon = "${icons.gemini}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "steno-jig";
        desktopName = "Steno Jig";
        exec = "${pkgs.brave}/bin/brave --app=https://joshuagrams.github.io/steno-jig/form.html --start-maximized";
        icon = "${icons.stenoJig}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "typey-type";
        desktopName = "Typey Type";
        exec = "${pkgs.brave}/bin/brave --app=https://didoesdigital.com/typey-type/lessons/ --start-maximized";
        icon = "${icons.typeyType}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Mail";
        desktopName = "Gmail Email";
        exec = "${pkgs.brave}/bin/brave --app=https://gmail.com --start-maximized";
        icon = "${icons.gmail}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Calendar";
        desktopName = "Calendar";
        exec = "${pkgs.brave}/bin/brave --app=https://calendar.google.com --start-maximized";
        icon = "${icons.calendar}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Toggl";
        desktopName = "Toggl Time Tracking";
        exec = "${pkgs.brave}/bin/brave --app=https://track.toggl.com/timer --start-maximized";
        icon = "${icons.toggl}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "syncthing";
        desktopName = "Syncthing";
        exec = "${pkgs.brave}/bin/brave --app=http://localhost:8385/ --start-maximized";
        icon = "${icons.syncthing}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Exercism";
        desktopName = "Exercism";
        exec = "${pkgs.brave}/bin/brave --app=https://exercism.org/dashboard --start-maximized";
        icon = "${icons.exercism}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "bitwarden-vault";
        desktopName = "Bitwarden Vault";
        exec = "${pkgs.brave}/bin/brave --app=https://vault.bitwarden.com --start-maximized";
        icon = "${icons.bitwarden}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "habitica";
        desktopName = "Habitica";
        exec = "${pkgs.brave}/bin/brave --app=https://habitica.com --start-maximized";
        icon = "${icons.habitica}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })
    ];
  };
}
