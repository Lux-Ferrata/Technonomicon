{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, ... }:
    let
      icon = url: sha256: pkgs.fetchurl { inherit url sha256; };
      icons = {
        khanAcademy  = icon "https://api.iconify.design/simple-icons:khanacademy.svg?width=128&height=128"  "06azkd71q5f9ibc20l33kvn8vx8zkx4b2z3f9c26zd6kk45m69lc";
        odinProject  = icon "https://api.iconify.design/simple-icons:theodinproject.svg?width=128&height=128" "1rqwdrn08974kamd7p044hl0slg8mdiaxcldpmj5dpmy93kpwccz";
        youtube      = icon "https://api.iconify.design/logos:youtube-icon.svg?width=128&height=128"          "000v6w4apb6dkwhk4c0qwsx06qnax6hs4nyr16jp9x0f6b15qr2p";
        gemini       = icon "https://api.iconify.design/logos:google-gemini.svg?width=128&height=128"         "02jq5rynxlca6h4pxp0n3ybzlw21yzgc62jg5ghdg11wwddrwxi6";
        stenoJig     = icon "https://api.iconify.design/tabler:keyboard.svg?width=128&height=128"             "062f03p0fnp1biyig9c3rlalzk37j52qf297484hjmrsfwmg51a6";
        typeyType    = icon "https://didoesdigital.com/typey-type/favicon-192x192.png"                        "0736jdsqnj0pj8m1gpqpqrhwgbf8diz6zwn2qp8xcd7rm8f3s54j";
        gmail        = pkgs.fetchurl { name = "gmail.svg"; sha256 = "01gvhxl2wxjmfj5fhdmr3l12ydlmkiqna5snpgk1nd4wjgzrs4ny"; url = "https://upload.wikimedia.org/wikipedia/commons/7/7e/Gmail_icon_%282020%29.svg"; };
        calendar     = icon "https://api.iconify.design/logos:google-calendar.svg?width=128&height=128"       "16m2wvm5rm5gqfv6zgrwbqkhb4jinbk1p5l3mdjdsmxrqcm0grj5";
        toggl        = icon "https://api.iconify.design/simple-icons:toggl.svg?width=128&height=128"          "1ljdq4vgzzxiflpjn4ag6yyzlh27fx2ljh41lyyw4zyanlq5ygwd";
        syncthing    = icon "https://api.iconify.design/simple-icons:syncthing.svg?width=128&height=128"      "1qkwh9029zslazknaacvpjvzs2dgblizf9k89pc8rhjr2hbzq80f";
        exercism     = icon "https://api.iconify.design/simple-icons:exercism.svg?width=128&height=128"       "1hcb0ny4yc45g50srmzzni1pxlkbbivghkknrzfsgpp1dsy1gpw7";
        bitwarden    = icon "https://api.iconify.design/simple-icons:bitwarden.svg?width=128&height=128"      "1d8djqdz0zar6p7nm2pvfkqq1xkd8fd0sx2q3wqmh72qwjbhpwx5";
        habitica     = icon "https://api.iconify.design/game-icons:dragon-head.svg?width=128&height=128"      "0k28xw0vhinaa1320nvgfmadlp9mc7svvs02isrj1m965ygb9bjg";
        amazon       = pkgs.fetchurl { name = "amazon.svg"; sha256 = "1xc3qdzp1gzhg8py1j9mzbj0ik9g66l35rfrby7d5pb5wi881kb9"; url = "https://api.iconify.design/simple-icons:amazon.svg?width=128&height=128"; };
        weather      = pkgs.fetchurl { name = "weather.svg"; sha256 = "1kj75df6j02phrbb6ziqihvc5rhxfc5p1z0gakjzqm72g8qvwn4d"; url = "https://api.iconify.design/simple-icons:theweatherchannel.svg?width=128&height=128"; };
        pima         = pkgs.fetchurl { name = "pima.svg"; sha256 = "0d0kw117lp3mna02zl61pzqa9khj9p6sgdk1pmd6h8hy7yaviksz"; url = "https://api.iconify.design/mdi:school.svg?width=128&height=128"; };
        ogs          = pkgs.fetchurl { name = "ogs.svg"; sha256 = "1v6fgy5d18fkaz5sv9h71kq91xmw3s1mpcyw2g2lrbd8v041cz6d"; url = "https://api.iconify.design/simple-icons:go.svg?width=128&height=128"; };
        tsumego      = pkgs.fetchurl { name = "tsumego.svg"; sha256 = "0hcldvigsh69fp1yvgjsmchxk9fj38rzfczczw60pf0h0373c1xa"; url = "https://api.iconify.design/game-icons:stone-pile.svg?width=128&height=128"; };
        kifubara     = pkgs.fetchurl { name = "kifubara.svg"; sha256 = "0xh0lqfyvyn1bfa4k5515dq0p1z57zii66154xfa5f3lnqp58g9m"; url = "https://api.iconify.design/game-icons:abstract-119.svg?width=128&height=128"; };
      };
    in {

    environment.systemPackages = [

      (pkgs.makeDesktopItem {
        name = "khan-academy";
        desktopName = "Khan Academy";
        exec = "${pkgs.brave}/bin/brave --app=https://www.khanacademy.org/profile/me/courses --start-maximized";
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

      (pkgs.makeDesktopItem {
        name = "amazon";
        desktopName = "Amazon";
        exec = "${pkgs.brave}/bin/brave --app=https://www.amazon.com/gp/css/order-history --start-maximized";
        icon = "${icons.amazon}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "weather";
        desktopName = "Weather";
        exec = "${pkgs.brave}/bin/brave --app=https://weather.com/us/arizona/city/tucson/tenday --start-maximized";
        icon = "${icons.weather}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "pima-community-college";
        desktopName = "Pima Community College";
        exec = "${pkgs.brave}/bin/brave --app=https://mypima.pima.edu/ --start-maximized";
        icon = "${icons.pima}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "ogs";
        desktopName = "OGS";
        exec = "${pkgs.brave}/bin/brave --app=https://online-go.com/play --start-maximized";
        icon = "${icons.ogs}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "tsumego-specialized-training";
        desktopName = "Tsumego: Specialized Training";
        exec = "${pkgs.brave}/bin/brave --app=https://www.101weiqi.com/training/ --start-maximized";
        icon = "${icons.tsumego}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "tsumego-test";
        desktopName = "Tsumego: Test";
        exec = "${pkgs.brave}/bin/brave --app=https://www.101weiqi.com/guan/ --start-maximized";
        icon = "${icons.tsumego}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "kifubara";
        desktopName = "Kifubara";
        exec = "${pkgs.brave}/bin/brave --app=https://kifubara.app/me/games --start-maximized";
        icon = "${icons.kifubara}";
        terminal = false;
        categories = [ "Application" "Network" ];
      })
    ];
  };
}
