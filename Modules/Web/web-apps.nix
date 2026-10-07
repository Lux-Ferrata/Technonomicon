{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, lib, ... }:
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
        calendar     = icon "google-calendar.svg"  "https://api.iconify.design/logos:google-calendar.svg?width=128&height=128"       "sha256-v4oOkriF27KZ5wcnDKow9Xs5vvOHXntKqaMRWbZkwJw="; # 2026-10-05: upstream iconify SVG changed, hash refreshed
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
        googleDrive  = icon "google-drive.svg"  "https://api.iconify.design/logos:google-drive.svg?width=128&height=128"             "sha256-rYGQpNUdENre/ZwZbAiOxihlTNtXUR4Cf7lvbEn5c2k="; # 2026-10-05: upstream iconify SVG changed, hash refreshed
        googleDocs   = icon "google-docs.svg"   "https://api.iconify.design/simple-icons:googledocs.svg?width=128&height=128"      "1jr8vcbz578z02zgc9cq6ss51x4dh8ckv8sg7kf4cdcxwvx7pnan";
        blog         = icon "blog.svg"          "https://api.iconify.design/mdi:post-outline.svg?width=128&height=128"               "0vfzawg165h3gdi5dkpzpwq551nj8y4l0ywsmj9mnbh1m719jwpi";
        desmos       = icon "desmos.svg"        "https://api.iconify.design/mdi:function-variant.svg?width=128&height=128"           "0njbnvs1p61vzr6k7v2vpdlf8yj76wy0yb0cf6zk664kbgdhbr6n";
        youtubeMusic = icon "youtube-music.svg" "https://api.iconify.design/simple-icons:youtubemusic.svg?width=128&height=128"    "0cyf745q476fxyly70cwy79rqvl3py0adxyarrwh16gb2gma9s2p";
        # Akmon's services (*.ironshark.org)
        immich         = icon "immich.svg"         "https://api.iconify.design/simple-icons:immich.svg?width=128&height=128"         "16j709sr80m32i2ga4sqn31bcks9hj5v1r3ryrwrlbkh85337xwh";
        jellyfin       = icon "jellyfin.svg"       "https://api.iconify.design/simple-icons:jellyfin.svg?width=128&height=128"       "0kj3pzgk1rvbkq22bfc8ip3l64f5m38bbg5kf8rxqv6jdl9b0avs";
        audiobookshelf = icon "audiobookshelf.svg" "https://api.iconify.design/simple-icons:audiobookshelf.svg?width=128&height=128" "0pdvwcm9dvaxb58sx24wnd2yrww96jmwkzqi8a6qkfxr9421pxgg";
        paperless      = icon "paperlessngx.svg"   "https://api.iconify.design/simple-icons:paperlessngx.svg?width=128&height=128"   "1cq562jx9mgmwgwn8pjcgghfzaiwsnlg6zkm555w563hj2f4ypzn";
        karakeep       = icon "bookmark-multiple.svg" "https://api.iconify.design/mdi:bookmark-multiple.svg?width=128&height=128"    "1xrk047csv8c5c9s4wc20r0scjgfgq2a13y64lk3jw42db1amnhq";
        miniflux       = icon "rss-box.svg"        "https://api.iconify.design/mdi:rss-box.svg?width=128&height=128"                 "1f398pgnqgkpslbyln4kcr6cjijhr9vp4v31m7knilqdv76cjrv7";
        forgejo        = icon "forgejo.svg"        "https://api.iconify.design/simple-icons:forgejo.svg?width=128&height=128"        "05m1r0141x3jirr5kgfyg2p1llpr2pla1rb713sx6z1dnb0f8qnf";
        cockpit        = icon "server.svg"         "https://api.iconify.design/mdi:server.svg?width=128&height=128"                  "1sapccdf29dzx76603ppz597p33jzh7bm9zyyrza0rdynl7pnqyb";
        qbittorrent    = icon "qbittorrent.svg"    "https://api.iconify.design/simple-icons:qbittorrent.svg?width=128&height=128"    "0wy7ypqfx436zhf7szgwy0dk1wzy5lg863npzpgkfl7qnh2s1pg8";
        pinchflat      = icon "television-classic.svg" "https://api.iconify.design/mdi:television-classic.svg?width=128&height=128"  "0kx4dssja7j4h9chndw2305ncj2v5yvzf09626f4s42q9bcy0a8c";
        radicale       = icon "calendar-sync.svg"  "https://api.iconify.design/mdi:calendar-sync.svg?width=128&height=128"           "1lvjm5wnynv67rdrx06aav4imhxwl8ilvzz72p6rq9y902dp2x58";
        opencloud      = icon "file-document-multiple.svg" "https://api.iconify.design/mdi:file-document-multiple.svg?width=128&height=128" "0cwkxdrmfh30zzf0240y8k2hppkszc60c377rdsf5yxykbaj9y53";
        vaultwarden    = icon "vaultwarden.svg"    "https://api.iconify.design/simple-icons:vaultwarden.svg?width=128&height=128"    "19fanbkz33wm9ayk36ai5xms9skwbqhijhms3danhrj5jxvmf4la";
      };

      # read-only copy of Vikunja for offline use (_tasks-offline.py)
      tasks-offline = pkgs.writers.writePython3Bin "tasks-offline" {
        flakeIgnore = [ "E501" "W503" ];
      } (builtins.readFile ./_tasks-offline.py);

      # one launcher entry per Akmon service with a web UI (tailnet-only).
      # Not here on purpose: tasks. (the Vikunja desktop app is the entry),
      # vault. (the Vaultwarden entry below), dav./lt./wopi./collabora. (no UI
      # of their own), metrics. (Grafana only draws the report charts).
      akmon = id: title: sub: path: ico: keywords: pkgs.makeDesktopItem {
        name = "akmon-${id}";
        desktopName = title;
        exec = "${pkgs.brave}/bin/brave --app=https://${sub}.ironshark.org${path} --start-maximized";
        icon = "${ico}";
        terminal = false;
        inherit keywords;
        categories = [ "Application" "Network" ];
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
        desktopName = "Syncthing (Kvasir)";
        exec = "${pkgs.brave}/bin/brave --app=http://localhost:8385/ --start-maximized";
        icon = "${icons.syncthing}";
        terminal = false;
        keywords = [ "syncthing" "sync" "files" "backup" "kvasir" ];
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
        desktopName = "Vaultwarden";
        exec = "${pkgs.brave}/bin/brave --app=https://vault.ironshark.org --start-maximized";
        icon = "${icons.vaultwarden}";
        terminal = false;
        keywords = [ "vaultwarden" "bitwarden" "vault" "password" "passwords" "credentials" ];
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

      (akmon "office"     "Office"            "office"     "/" icons.opencloud      [ "office" "opencloud" "documents" "files" "word" "spreadsheet" "collabora" ])
      (akmon "photos"     "Photos"            "photos"     "/" icons.immich         [ "photos" "immich" "pictures" "images" "gallery" ])
      (akmon "media"      "Jellyfin"          "media"      "/" icons.jellyfin       [ "jellyfin" "media" "movies" "tv" "shows" ])
      (akmon "audiobooks" "Audiobooks"        "audiobooks" "/" icons.audiobookshelf [ "audiobooks" "audiobookshelf" "podcasts" "books" ])
      (akmon "docs"       "Paperless"         "docs"       "/" icons.paperless      [ "paperless" "documents" "scans" "receipts" ])
      (akmon "keep"       "Karakeep"          "keep"       "/" icons.karakeep       [ "karakeep" "bookmarks" "read" "later" ])
      (akmon "rss"        "Miniflux"          "rss"        "/" icons.miniflux       [ "miniflux" "rss" "feeds" "news" "reader" ])
      (akmon "git"        "Forgejo"           "git"        "/" icons.forgejo        [ "forgejo" "git" "repos" "issues" "forge" ])
      (akmon "admin"      "Cockpit"           "admin"      "/" icons.cockpit        [ "cockpit" "admin" "server" "akmon" "vms" "containers" ])
      (akmon "torrent"    "qBittorrent"       "torrent"    "/" icons.qbittorrent    [ "qbittorrent" "torrent" "downloads" ])
      # no "youtube" keyword, so searching "youtube" still finds only YouTube
      (akmon "yt"         "Pinchflat"         "yt"         "/" icons.pinchflat      [ "pinchflat" "channels" "downloads" "videos" ])
      (akmon "cal"        "Radicale Calendar" "cal"        "/infcloud/" icons.radicale [ "radicale" "infcloud" "caldav" "calendars" ])
      (akmon "sync"       "Syncthing (Akmon)" "sync"       "/" icons.syncthing      [ "syncthing" "sync" "akmon" "server" ])

      (pkgs.makeDesktopItem {
        name = "tasks-offline";
        desktopName = "Tasks (offline copy)";
        exec = "${pkgs.brave}/bin/brave --app=file:///home/xin/.local/share/tasks-offline/index.html";
        icon = "${icons.radicale}";
        terminal = false;
        keywords = [ "tasks" "todo" "offline" "vikunja" ];
        categories = [ "Application" "Office" ];
      })
    ];

    # ── Tasks offline: Vikunja stays the place to edit (desktop app); this
    # keeps a read-only page of every open task, refreshed every 15 min while
    # Akmon is reachable, for when it isn't
    sops.secrets.vikunja-password = { owner = "xin"; mode = "0400"; };
    home-manager.users.xin.systemd.user = {
      services.tasks-offline = {
        Unit.Description = "Save a read-only offline copy of Vikunja's tasks";
        Service = {
          Type = "oneshot";
          Environment = "VIKUNJA_PASSWORD_FILE=${config.sops.secrets.vikunja-password.path}";
          ExecStart   = "${tasks-offline}/bin/tasks-offline";
        };
      };
      timers.tasks-offline = {
        Unit.Description = "Refresh the offline copy of Vikunja's tasks";
        Timer = { OnCalendar = "*:0/15"; OnStartupSec = "1min"; Persistent = true; };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    # the syncthing package's own "Syncthing Web UI" entry would be a second
    # Syncthing in the launcher; a same-named user entry hides it
    home-manager.users.xin.xdg.desktopEntries.syncthing-ui = {
      name     = "Syncthing Web UI";
      exec     = "syncthing browser";
      noDisplay = true;
    };
  };
}
