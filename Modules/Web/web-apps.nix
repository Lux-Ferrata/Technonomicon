{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, ... }:
    let
      icon = name: url: sha256: pkgs.fetchurl { inherit name url sha256; };
      icons = {
        khanAcademy  = icon "khanacademy.svg"    "https://api.iconify.design/simple-icons:khanacademy.svg?width=128&height=128"     "06azkd71q5f9ibc20l33kvn8vx8zkx4b2z3f9c26zd6kk45m69lc";
        odinProject  = icon "theodinproject.svg" "https://api.iconify.design/simple-icons:theodinproject.svg?width=128&height=128"   "1rqwdrn08974kamd7p044hl0slg8mdiaxcldpmj5dpmy93kpwccz";
        youtube      = icon "youtube-icon.svg"   "https://api.iconify.design/logos:youtube-icon.svg?width=128&height=128"            "000v6w4apb6dkwhk4c0qwsx06qnax6hs4nyr16jp9x0f6b15qr2p";
        gemini       = icon "google-gemini.svg"  "https://api.iconify.design/logos:google-gemini.svg?width=128&height=128"           "02jq5rynxlca6h4pxp0n3ybzlw21yzgc62jg5ghdg11wwddrwxi6";
        stenoJig     = icon "keyboard.svg"       "https://api.iconify.design/tabler:keyboard.svg?width=128&height=128"               "062f03p0fnp1biyig9c3rlalzk37j52qf297484hjmrsfwmg51a6";
        typeyType    = icon "typey-type.png"     "https://didoesdigital.com/typey-type/favicon-192x192.png"                          "0736jdsqnj0pj8m1gpqpqrhwgbf8diz6zwn2qp8xcd7rm8f3s54j";
        gmail        = pkgs.fetchurl { name = "gmail.svg"; sha256 = "01gvhxl2wxjmfj5fhdmr3l12ydlmkiqna5snpgk1nd4wjgzrs4ny"; url = "https://upload.wikimedia.org/wikipedia/commons/7/7e/Gmail_icon_%282020%29.svg"; };
        calendar     = icon "google-calendar.svg"  "https://api.iconify.design/logos:google-calendar.svg?width=128&height=128"       "16m2wvm5rm5gqfv6zgrwbqkhb4jinbk1p5l3mdjdsmxrqcm0grj5";
        toggl        = icon "toggl.svg"            "https://api.iconify.design/simple-icons:toggl.svg?width=128&height=128"          "1ljdq4vgzzxiflpjn4ag6yyzlh27fx2ljh41lyyw4zyanlq5ygwd";
        syncthing    = icon "syncthing.svg"        "https://api.iconify.design/simple-icons:syncthing.svg?width=128&height=128"      "1qkwh9029zslazknaacvpjvzs2dgblizf9k89pc8rhjr2hbzq80f";
        exercism     = icon "exercism.svg"         "https://api.iconify.design/simple-icons:exercism.svg?width=128&height=128"       "1hcb0ny4yc45g50srmzzni1pxlkbbivghkknrzfsgpp1dsy1gpw7";
        bitwarden    = icon "bitwarden.svg"        "https://api.iconify.design/simple-icons:bitwarden.svg?width=128&height=128"      "1d8djqdz0zar6p7nm2pvfkqq1xkd8fd0sx2q3wqmh72qwjbhpwx5";
        habitica     = icon "dragon-head.svg"      "https://api.iconify.design/game-icons:dragon-head.svg?width=128&height=128"      "0k28xw0vhinaa1320nvgfmadlp9mc7svvs02isrj1m965ygb9bjg";
        amazon       = pkgs.fetchurl { name = "amazon.svg";  sha256 = "1xc3qdzp1gzhg8py1j9mzbj0ik9g66l35rfrby7d5pb5wi881kb9"; url = "https://api.iconify.design/simple-icons:amazon.svg?width=128&height=128"; };
        weather      = pkgs.fetchurl { name = "weather.svg"; sha256 = "1kj75df6j02phrbb6ziqihvc5rhxfc5p1z0gakjzqm72g8qvwn4d"; url = "https://api.iconify.design/simple-icons:theweatherchannel.svg?width=128&height=128"; };
        pima         = pkgs.fetchurl { name = "pima.svg";    sha256 = "0d0kw117lp3mna02zl61pzqa9khj9p6sgdk1pmd6h8hy7yaviksz"; url = "https://api.iconify.design/mdi:school.svg?width=128&height=128"; };
        d2l          = pkgs.fetchurl { name = "d2l.svg";     sha256 = "0sz6pkijy4gfky564d8c62829zj3vpc8060ydgvcwa9ff237b48c"; url = "https://api.iconify.design/mdi:book-education.svg?width=128&height=128"; };
        ogs          = pkgs.fetchurl { name = "ogs.svg";     sha256 = "1v6fgy5d18fkaz5sv9h71kq91xmw3s1mpcyw2g2lrbd8v041cz6d"; url = "https://api.iconify.design/simple-icons:go.svg?width=128&height=128"; };
        tsumego      = pkgs.fetchurl { name = "tsumego.svg"; sha256 = "0hcldvigsh69fp1yvgjsmchxk9fj38rzfczczw60pf0h0373c1xa"; url = "https://api.iconify.design/game-icons:stone-pile.svg?width=128&height=128"; };
        kifubara     = pkgs.fetchurl { name = "kifubara.svg"; sha256 = "0xh0lqfyvyn1bfa4k5515dq0p1z57zii66154xfa5f3lnqp58g9m"; url = "https://api.iconify.design/game-icons:abstract-119.svg?width=128&height=128"; };
        googleDrive  = icon "google-drive.svg"  "https://api.iconify.design/logos:google-drive.svg?width=128&height=128"             "0106wgz3hh84r7xi3fqfqz29f32n5rjnxm3fsslkfwwx61nnxlmj";
        googleDocs   = icon "google-docs.svg"   "https://api.iconify.design/simple-icons:googledocs.svg?width=128&height=128"      "1jr8vcbz578z02zgc9cq6ss51x4dh8ckv8sg7kf4cdcxwvx7pnan";
        blog         = icon "blog.svg"          "https://api.iconify.design/mdi:post-outline.svg?width=128&height=128"               "0vfzawg165h3gdi5dkpzpwq551nj8y4l0ywsmj9mnbh1m719jwpi";
        desmos       = icon "desmos.svg"        "https://api.iconify.design/mdi:function-variant.svg?width=128&height=128"           "0njbnvs1p61vzr6k7v2vpdlf8yj76wy0yb0cf6zk664kbgdhbr6n";
        youtubeMusic = icon "youtube-music.svg" "https://api.iconify.design/simple-icons:youtubemusic.svg?width=128&height=128"    "0cyf745q476fxyly70cwy79rqvl3py0adxyarrwh16gb2gma9s2p";
      };
    in {

    environment.systemPackages = [

      (pkgs.makeDesktopItem {
        name = "youtube-music";
        # Named just "Music" and with no "youtube" keyword, so searching
        # "youtube" in the launcher returns only the YouTube entry.
        desktopName = "Music";
        exec = "${pkgs.brave}/bin/brave --app=https://music.youtube.com --start-maximized";
        icon = "${icons.youtubeMusic}";
        terminal = false;
        keywords = [ "music" "ytm" "audio" "player" "songs" ];
        categories = [ "Application" "AudioVideo" "Audio" ];
      })

      (pkgs.makeDesktopItem {
        name = "desmos";
        desktopName = "Desmos";
        exec = "${pkgs.brave}/bin/brave --app=https://www.desmos.com/calculator --start-maximized";
        icon = "${icons.desmos}";
        terminal = false;
        keywords = [ "desmos" "graph" "graphing" "calculator" "math" "plot" ];
        categories = [ "Application" "Education" "Science" ];
      })

      (pkgs.makeDesktopItem {
        name = "khan-academy";
        desktopName = "Khan Academy";
        exec = "${pkgs.brave}/bin/brave --app=https://www.khanacademy.org/profile/me/courses --start-maximized";
        icon = "${icons.khanAcademy}";
        terminal = false;
        keywords = [ "khan" "academy" "courses" "learning" "study" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "the-odin-project";
        desktopName = "TOP: The Odin Project";
        exec = "${pkgs.brave}/bin/brave --app=https://www.theodinproject.com/dashboard --start-maximized";
        icon = "${icons.odinProject}";
        terminal = false;
        keywords = [ "odin" "top" "webdev" "programming" "learning" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "youtube";
        desktopName = "YouTube";
        exec = "${pkgs.brave}/bin/brave --app=https://www.youtube.com/feed/subscriptions --start-maximized";
        icon = "${icons.youtube}";
        terminal = false;
        keywords = [ "youtube" "yt" "video" "videos" "subscriptions" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "gemini";
        desktopName = "Gemini";
        exec = "${pkgs.brave}/bin/brave --app=https://gemini.google.com/app --start-maximized";
        icon = "${icons.gemini}";
        terminal = false;
        keywords = [ "gemini" "google" "ai" "chat" "llm" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "steno-jig";
        desktopName = "Steno Jig";
        exec = "${pkgs.brave}/bin/brave --app=https://joshuagrams.github.io/steno-jig/form.html --start-maximized";
        icon = "${icons.stenoJig}";
        terminal = false;
        keywords = [ "steno" "stenography" "typing" "drills" "plover" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "typey-type";
        desktopName = "Typey Type";
        exec = "${pkgs.brave}/bin/brave --app=https://didoesdigital.com/typey-type/lessons/ --start-maximized";
        icon = "${icons.typeyType}";
        terminal = false;
        keywords = [ "typey" "steno" "stenography" "typing" "lessons" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Mail";
        desktopName = "Gmail Email";
        exec = "${pkgs.brave}/bin/brave --app=https://gmail.com --start-maximized";
        icon = "${icons.gmail}";
        terminal = false;
        keywords = [ "gmail" "mail" "email" "google" "inbox" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Calendar";
        desktopName = "Calendar";
        exec = "${pkgs.brave}/bin/brave --app=https://calendar.google.com --start-maximized";
        icon = "${icons.calendar}";
        terminal = false;
        keywords = [ "gcal" "calendar" "google" "schedule" "agenda" "events" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Toggl";
        desktopName = "Toggl Time Tracking";
        exec = "${pkgs.brave}/bin/brave --app=https://track.toggl.com/timer --start-maximized";
        icon = "${icons.toggl}";
        terminal = false;
        keywords = [ "toggl" "time" "tracking" "timer" "timesheet" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "syncthing";
        desktopName = "Syncthing";
        exec = "${pkgs.brave}/bin/brave --app=http://localhost:8385/ --start-maximized";
        icon = "${icons.syncthing}";
        terminal = false;
        keywords = [ "syncthing" "sync" "files" "backup" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "Exercism";
        desktopName = "Exercism";
        exec = "${pkgs.brave}/bin/brave --app=https://exercism.org/dashboard --start-maximized";
        icon = "${icons.exercism}";
        terminal = false;
        keywords = [ "exercism" "exercises" "practice" "programming" "coding" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "bitwarden-vault";
        desktopName = "Bitwarden Vault";
        exec = "${pkgs.brave}/bin/brave --app=https://vault.bitwarden.com --start-maximized";
        icon = "${icons.bitwarden}";
        terminal = false;
        keywords = [ "bitwarden" "vault" "password" "passwords" "credentials" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "habitica";
        desktopName = "Habitica";
        exec = "${pkgs.brave}/bin/brave --app=https://habitica.com --start-maximized";
        icon = "${icons.habitica}";
        terminal = false;
        keywords = [ "habitica" "habits" "todo" "tasks" "rpg" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "amazon";
        desktopName = "Amazon";
        exec = "${pkgs.brave}/bin/brave --app=https://www.amazon.com/gp/css/order-history --start-maximized";
        icon = "${icons.amazon}";
        terminal = false;
        keywords = [ "amazon" "orders" "shopping" "shop" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "weather";
        desktopName = "Weather";
        exec = "${pkgs.brave}/bin/brave --app=https://weather.com/us/arizona/city/tucson/tenday --start-maximized";
        icon = "${icons.weather}";
        terminal = false;
        keywords = [ "weather" "forecast" "temperature" "tucson" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "pima-community-college";
        desktopName = "Pima Community College";
        exec = "${pkgs.brave}/bin/brave --app=https://mypima.pima.edu/ --start-maximized";
        icon = "${icons.pima}";
        terminal = false;
        keywords = [ "pima" "mypima" "college" "school" "courses" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "d2l";
        desktopName = "D2L";
        exec = "${pkgs.brave}/bin/brave --app=https://d2l.pima.edu/ --start-maximized";
        icon = "${icons.d2l}";
        terminal = false;
        keywords = [ "d2l" "brightspace" "pima" "college" "school" "courses" "lms" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "ogs";
        desktopName = "OGS";
        exec = "${pkgs.brave}/bin/brave --app=https://online-go.com/play --start-maximized";
        icon = "${icons.ogs}";
        terminal = false;
        keywords = [ "ogs" "go" "baduk" "weiqi" "online-go" "games" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "tsumego-specialized-training";
        desktopName = "Tsumego: Specialized Training";
        exec = "${pkgs.brave}/bin/brave --app=https://www.101weiqi.com/training/ --start-maximized";
        icon = "${icons.tsumego}";
        terminal = false;
        keywords = [ "tsumego" "go" "baduk" "weiqi" "training" "problems" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "tsumego-test";
        desktopName = "Tsumego: Test";
        exec = "${pkgs.brave}/bin/brave --app=https://www.101weiqi.com/guan/ --start-maximized";
        icon = "${icons.tsumego}";
        terminal = false;
        keywords = [ "tsumego" "go" "baduk" "weiqi" "test" "problems" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "kifubara";
        desktopName = "Kifubara";
        exec = "${pkgs.brave}/bin/brave --app=https://kifubara.app/me/games --start-maximized";
        icon = "${icons.kifubara}";
        terminal = false;
        keywords = [ "kifubara" "kifu" "go" "baduk" "weiqi" "games" "records" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "google-drive";
        desktopName = "Google Drive";
        exec = "${pkgs.brave}/bin/brave --app=https://drive.google.com/drive/my-drive --start-maximized";
        icon = "${icons.googleDrive}";
        terminal = false;
        keywords = [ "gdrive" "drive" "google" "files" "storage" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "G-Documents";
        desktopName = "Google Documents";
        exec = "${pkgs.brave}/bin/brave --app=https://docs.google.com/ --start-maximized";
        icon = "${icons.googleDocs}";
        terminal = false;
        keywords = [ "gdoc" "gdocs" "google" "docs" "documents" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "blog";
        desktopName = "Blog";
        exec = "${pkgs.brave}/bin/brave --app=https://lux-ferrata.org --start-maximized";
        icon = "${icons.blog}";
        terminal = false;
        keywords = [ "blog" "lux-ferrata" "website" "posts" ];
        categories = [ "Application" "Network" ];
      })
    ];
  };
}
