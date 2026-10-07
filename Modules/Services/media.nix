{ inputs, ... }: {
  # Media server stack on Akmon. PLACEHOLDER LAYOUT: the media library is
  # being reorganised; every path hangs off tn.media.root so the move is one
  # line here (plus re-pointing libraries in each app).
  #
  #   https://media.ironshark.org       Jellyfin: video, music (NVENC transcode)
  #   https://audiobooks.ironshark.org  Audiobookshelf: audiobooks, podcasts
  #   https://yt.ironshark.org          Pinchflat: YouTube channels/playlists
  #   ytdl URL... [--audio]             one-off downloads (yt-dlp)
  #
  # Libraries are added in each app's UI on first run. Files are group
  # `media` (xin and the three services), setgid, so everyone can read and
  # write what the others add.
  flake.nixosModules.Tn-media = { config, lib, pkgs, ... }:
  let
    root = config.tn.media.root;
    dirs = [ "video" "music" "audiobooks" "podcasts" "youtube" "youtube/manual" ];

    ytdl = pkgs.writeShellApplication {
      name = "ytdl";
      runtimeInputs = [ pkgs.yt-dlp pkgs.ffmpeg-headless ];
      text = ''
        # ytdl URL... [--audio]: video into youtube/manual, or audio into music
        audio=0; urls=()
        for a in "$@"; do
          case "$a" in
            --audio) audio=1 ;;
            -h|--help) echo "Usage: ytdl URL... [--audio]"; exit 0 ;;
            *) urls+=("$a") ;;
          esac
        done
        [ ''${#urls[@]} -gt 0 ] || { echo "Usage: ytdl URL... [--audio]" >&2; exit 2; }
        umask 002
        if [ "$audio" = 1 ]; then
          exec yt-dlp -x --audio-format opus --embed-metadata --embed-thumbnail \
            -o "${root}/music/%(artist,uploader)s/%(title)s.%(ext)s" "''${urls[@]}"
        fi
        exec yt-dlp -f "bv*[height<=1080]+ba/b" --merge-output-format mkv \
          --embed-metadata --embed-subs --sub-langs "en.*,zh.*" --embed-chapters \
          -o "${root}/youtube/manual/%(uploader)s/%(title)s [%(id)s].%(ext)s" "''${urls[@]}"
      '';
    };
  in {
    options.tn.media.root = lib.mkOption {
      type    = lib.types.str;
      default = "/srv/media";
      description = "Root of the media library (placeholder until the new layout).";
    };

    config = {
      users.groups.media = {};
      users.users.xin.extraGroups = [ "media" ];
      systemd.tmpfiles.rules = [ "d ${root} 2775 xin media -" ]
        ++ map (d: "d ${root}/${d} 2775 xin media -") dirs;
      environment.systemPackages = [ ytdl pkgs.yt-dlp ];

      # ── Jellyfin ──────────────────────────────────────────────────────
      services.jellyfin = {
        enable  = true;
        dataDir = "/srv/jellyfin";
        hardwareAcceleration = { enable = true; type = "nvenc"; device = "/dev/nvidia0"; };
      };
      users.users.jellyfin.extraGroups = [ "media" "video" "render" ];
      systemd.services.jellyfin = {
        unitConfig.RequiresMountsFor = [ "/srv/jellyfin" root ];
        serviceConfig.DeviceAllow = [ "/dev/nvidiactl rw" "/dev/nvidia-uvm rw" "/dev/nvidia-uvm-tools rw" ];
      };
      tn.web.vhosts.media = { port = 8096; maxBody = "100m"; };

      # ── Audiobookshelf ────────────────────────────────────────────────
      services.audiobookshelf = { enable = true; port = 13378; };
      users.users.audiobookshelf.extraGroups = [ "media" ];
      environment.persistence."/persist".directories = [
        { directory = "/var/lib/audiobookshelf"; user = "audiobookshelf"; group = "audiobookshelf"; mode = "0750"; }
        { directory = "/var/lib/pinchflat";      user = "pinchflat";      group = "pinchflat";      mode = "0750"; }
      ];
      systemd.services.audiobookshelf.unitConfig.RequiresMountsFor = [ root ];
      tn.web.vhosts.audiobooks = { port = 13378; maxBody = "2g"; };   # uploads

      # ── Pinchflat ─────────────────────────────────────────────────────
      sops.secrets.pinchflat-secret-key = {};
      sops.templates."pinchflat.env".content =
        "SECRET_KEY_BASE=${config.sops.placeholder.pinchflat-secret-key}\n";
      services.pinchflat = {
        enable      = true;
        mediaDir    = "${root}/youtube";
        secretsFile = config.sops.templates."pinchflat.env".path;
        extraConfig = { TZ = config.time.timeZone; UMASK = "002"; };
      };
      users.users.pinchflat.extraGroups = [ "media" ];
      systemd.services.pinchflat = {
        unitConfig.RequiresMountsFor = [ root ];
        serviceConfig.ReadWritePaths = [ "${root}/youtube" ];
      };
      tn.web.vhosts.yt = { port = 8945; };
    };
  };
}
