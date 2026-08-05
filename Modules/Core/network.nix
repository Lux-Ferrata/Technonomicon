{ inputs, ... }: {
  flake.nixosModules.Tn-network = { pkgs, ... }: {

    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.backend = "iwd";

    networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];
    networking.extraHosts = ''
        127.0.0.1 reddit.com
        127.0.0.1 www.reddit.com
        127.0.0.1 old.reddit.com
        ::1 reddit.com
        ::1 www.reddit.com
        ::1 old.reddit.com

        127.0.0.1 twitter.com
        127.0.0.1 www.twitter.com
        127.0.0.1 x.com
        127.0.0.1 www.x.com
        ::1 twitter.com
        ::1 www.twitter.com
        ::1 x.com
        ::1 www.x.com

        127.0.0.1 facebook.com
        127.0.0.1 www.facebook.com
        127.0.0.1 m.facebook.com
        ::1 facebook.com
        ::1 www.facebook.com
        ::1 m.facebook.com

        127.0.0.1 instagram.com
        127.0.0.1 www.instagram.com
        ::1 instagram.com
        ::1 www.instagram.com

        127.0.0.1 tiktok.com
        127.0.0.1 www.tiktok.com
        ::1 tiktok.com
        ::1 www.tiktok.com

        127.0.0.1 linkedin.com
        127.0.0.1 www.linkedin.com
        ::1 linkedin.com
        ::1 www.linkedin.com

        127.0.0.1 tumblr.com
        127.0.0.1 www.tumblr.com
        ::1 tumblr.com
        ::1 www.tumblr.com

        127.0.0.1 snapchat.com
        127.0.0.1 www.snapchat.com
        ::1 snapchat.com
        ::1 www.snapchat.com

        127.0.0.1 news.google.com
        ::1 news.google.com
    '';

    time.timeZone = "America/New_York";

    environment.systemPackages = with pkgs; [
      impala
      gping
    ];

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 7236 7250 ];
      allowedUDPPorts = [ 7236 ];
    };

    networking.firewall.trustedInterfaces = [ "p2p-wl+" ];

    services.resolved.enable = true;

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="net", KERNEL=="p2p-dev-*", ACTION=="add", TAG-="systemd"
    '';

    programs = {
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
    };

    services = {
      openssh = {
        enable = false;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };

      printing.enable = true;

      syncthing = {
        enable = true;
        openDefaultPorts = true;
        guiAddress = "127.0.0.1:8385";
        user = "xin";
        group = "users";
        dataDir = "/home/xin/";
      };
    };
  };
}
