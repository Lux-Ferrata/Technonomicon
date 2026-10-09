{ inputs, ... }: {
  flake.nixosModules.Tn-web-apps = { pkgs, config, lib, ... }:
    let
      # Launcher icons, kept in the repo (icons/SOURCES says where each came
      # from): fetched and pinned by hash, they broke the build whenever
      # upstream redrew an SVG.
      icons = lib.mapAttrs (_: file: ./icons + "/${file}") {
        khanAcademy    = "khanacademy.svg";
        odinProject    = "theodinproject.svg";
        youtube        = "youtube-icon.svg";
        gemini         = "google-gemini.svg";
        stenoJig       = "keyboard.svg";
        typeyType      = "typey-type.png";
        gmail          = "gmail.svg";
        calendar       = "google-calendar.svg";
        toggl          = "toggl.svg";
        syncthing      = "syncthing.svg";
        exercism       = "exercism.svg";
        amazon         = "amazon.svg";
        weather        = "weather.svg";
        pima           = "pima.svg";
        d2l            = "d2l.svg";
        ogs            = "ogs.svg";
        tsumego        = "tsumego.svg";
        kifubara       = "kifubara.svg";
        googleDrive    = "google-drive.svg";
        googleDocs     = "google-docs.svg";
        blog           = "blog.svg";
        desmos         = "desmos.svg";
        youtubeMusic   = "youtube-music.svg";
        matplotlib     = "matplotlib.svg";
        va             = "flag.svg";
        wifiLogin      = "wifi-lock.svg";
        # Akmon's services (*.ironshark.org)
        immich         = "immich.svg";
        jellyfin       = "jellyfin.svg";
        audiobookshelf = "audiobookshelf.svg";
        paperless      = "paperlessngx.svg";
        karakeep       = "bookmark-multiple.svg";
        miniflux       = "rss-box.svg";
        forgejo        = "forgejo.svg";
        cockpit        = "server.svg";
        qbittorrent    = "qbittorrent.svg";
        pinchflat      = "television-classic.svg";
        opencloud      = "file-document-multiple.svg";
        vaultwarden    = "vaultwarden.svg";
        flowchart      = "sitemap-outline.svg";
      };

      # one launcher entry per Akmon service with a web UI (tailnet-only).
      # Not here on purpose: vault. (the Vaultwarden entry below), dav./lt./wopi./collabora. (no UI
      # of their own), metrics. (Grafana only draws the report charts), cal. (only
      # stages generated calendars; calendars are edited in Google).
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
        name = "matplotlib-discourse";
        desktopName = "Matplotlib Discourse";
        exec = "${pkgs.brave}/bin/brave --app=https://discourse.matplotlib.org/ --start-maximized";
        icon = "${icons.matplotlib}";
        terminal = false;
        keywords = [ "matplotlib" "discourse" "forum" "python" "plotting" "mpl" ];
        categories = [ "Application" "Network" ];
      })

      (pkgs.makeDesktopItem {
        name = "va-gov";
        desktopName = "VA";
        exec = "${pkgs.brave}/bin/brave --app=https://www.va.gov/my-va/ --start-maximized";
        icon = "${icons.va}";
        terminal = false;
        keywords = [ "va" "veterans" "affairs" "benefits" "health" "gi bill" "claims" ];
        categories = [ "Application" "Network" ];
      })

      # Captive portals can only intercept plain HTTP, so this opens a page
      # that is guaranteed never to use HTTPS and lets the portal redirect it.
      (pkgs.makeDesktopItem {
        name = "wifi-login";
        desktopName = "WiFi Login";
        exec = "${pkgs.brave}/bin/brave --app=http://neverssl.com --start-maximized";
        icon = "${icons.wifiLogin}";
        terminal = false;
        keywords = [ "wifi" "login" "captive" "portal" "hotspot" "neverssl" "network" ];
        categories = [ "Application" "Network" ];
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
      (akmon "draw"       "Flowchart"         "draw"       "/" icons.flowchart      [ "flowchart" "diagram" "whiteboard" "excalidraw" "astradraw" "drawing" ])
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
      (akmon "sync"       "Syncthing (Akmon)" "sync"       "/" icons.syncthing      [ "syncthing" "sync" "akmon" "server" ])
    ];

    # the syncthing package's own "Syncthing Web UI" entry would be a second
    # Syncthing in the launcher; a same-named user entry hides it
    home-manager.users.xin.xdg.desktopEntries.syncthing-ui = {
      name     = "Syncthing Web UI";
      exec     = "syncthing browser";
      noDisplay = true;
    };
  };
}
