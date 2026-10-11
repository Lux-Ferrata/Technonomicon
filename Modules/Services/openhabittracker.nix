{ inputs, ... }: {
  # OpenHabitTracker at https://habits.ironshark.org: habits, tasks and notes
  # (github.com/Jinjinov/OpenHabitTracker, GPL-3.0). The apps -- Kvasir's
  # Flathub one (Tn-mind) and the phone's from Google Play -- keep all data
  # on the device and work offline; this server is what they sync through
  # (Data > Online sync: address https://habits.ironshark.org, user xin,
  # password sops openhabittracker-password). It also serves a web version.
  #
  # One user, made from the environment on first start; changing the
  # password here later doesn't change the existing account. Upstream ships
  # a container image (.NET), run under podman and pinned by digest. Its
  # SQLite database and the cookie keys live in /srv/openhabittracker,
  # snapshotted by sanoid.
  flake.nixosModules.Tn-openhabittracker = { config, lib, pkgs, ... }:
  let
    port = 3050;
    data = "/srv/openhabittracker";
  in {
    sops.secrets = {
      openhabittracker-password   = {};
      openhabittracker-jwt-secret = {};
    };
    # read by podman (root) into the container's environment
    sops.templates."openhabittracker.env".content = ''
      AppSettings__Password=${config.sops.placeholder.openhabittracker-password}
      AppSettings__JwtSecret=${config.sops.placeholder.openhabittracker-jwt-secret}
    '';

    systemd.tmpfiles.rules = [ "d ${data} 0700 root root -" ];

    virtualisation.oci-containers.containers.openhabittracker = {
      image = "ghcr.io/jinjinov/openhabittracker:1.2.5@sha256:c040b1b7c961554a6e60c2b84d916298056d9703f5e1da5b1e54b2720f14177b";
      ports = [ "127.0.0.1:${toString port}:8080" ];
      volumes = [ "${data}:/app/.OpenHabitTracker" ];
      environment = {
        ASPNETCORE_ENVIRONMENT = "Production";
        AppSettings__UserName  = "xin";
        AppSettings__Email     = "xin@ironshark.org";
        TZ                     = config.time.timeZone;
      };
      environmentFiles = [ config.sops.templates."openhabittracker.env".path ];
    };

    tn.web.vhosts.habits = { inherit port; };
  };
}
