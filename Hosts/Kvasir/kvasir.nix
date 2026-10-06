{ self, inputs, config, ... }: {
  flake.nixosConfigurations.Kvasir = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";

    specialArgs = {
      inherit inputs;
      pkgs-stable = import inputs.nixpkgs-stable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };

    modules = [
      ./_hardware-configuration.nix

      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager

      # throttled 0.12 (pulled in by the t480s hardware module above) added a
      # dbus-next dependency that nixpkgs' package doesn't propagate yet, so
      # the service crashes with a ModuleNotFoundError on startup. Patch it
      # in until upstream catches up.
      ({ ... }: {
        nixpkgs.overlays = [
          (final: prev: {
            throttled = prev.throttled.overrideAttrs (old: {
              pythonPath = old.pythonPath ++ [ final.python3Packages.dbus-next ];
            });
          })
        ];
      })

      self.nixosModules.Tn-user-settings
      self.nixosModules.Tn-theme
      self.nixosModules.Tn-nix
      self.nixosModules.Tn-desktop
      self.nixosModules.Tn-hyprland
      self.nixosModules.Tn-neovim
      self.nixosModules.Tn-web-browsers
      self.nixosModules.Tn-web-apps
      self.nixosModules.Tn-network
      self.nixosModules.Tn-communication
      self.nixosModules.Tn-email
      self.nixosModules.Tn-sound
      self.nixosModules.Tn-shell
      self.nixosModules.Tn-pdf
      self.nixosModules.Tn-scan
      self.nixosModules.Tn-print
      self.nixosModules.Tn-games
      self.nixosModules.Tn-learning
      # NOTE: sage is not in the binary cache -- building this module compiles
      # sage 10.9 from source AND runs its full doctest suite. Expect hours.
      self.nixosModules.Tn-science
      self.nixosModules.Tn-mind
      self.nixosModules.Tn-provenance
      self.nixosModules.Tn-art
      self.nixosModules.Tn-utf
      self.nixosModules.Tn-virtualization
      self.nixosModules.Tn-build-client

      ({ pkgs, config, ... }: {
        system.stateVersion = "23.11";

        tn.full_name          = "xin";
        tn.email_address      = "git@ironshark.org";
        tn.theme              = "nord";
        tn.primary_font       = "Iosevka";
        tn.scale              = 1;
        tn.quick_app_bindings = {};
        # tn.wallpaper_path  = "/home/xin/Projects/Technonomicon/.wallpapers/wallpaper.png";

        boot.kernelModules = [ "uinput" ];
        boot.kernelPackages = pkgs.linuxPackages;
        boot.blacklistedKernelModules = [ "wacom" ];
        boot.loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
          efi.efiSysMountPoint = "/boot";
        };

        hardware = {
          uinput.enable = true;
          opentabletdriver = {
            enable = true;
            daemon.enable = true;
          };
        };

        sops.secrets.xin-password.neededForUsers = true;
        sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        sops.defaultSopsFile = ../../_secrets.yaml;
        sops.defaultSopsFormat = "yaml";

        networking.hostName = "Kvasir";

        environment.systemPackages = [ pkgs.vikunja-desktop ];

        # Local-only Vikunja server for the desktop app (Custom server URL →
        # http://localhost:3456). SQLite + attachments live in
        # /var/lib/private/vikunja (DynamicUser).
        services.vikunja = {
          enable           = true;
          address          = "127.0.0.1";
          port             = 3456;
          frontendScheme   = "http";
          frontendHostname = "localhost:3456";
        };

        services.logind.settings.Login.HandleLidSwitch = "suspend";

        # tailnet client: reaches and deploys to Akmon (ssh xin@akmon)
        services.tailscale.enable = true;

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
          users.xin.home.stateVersion = "23.11";
        };

        users = {
          mutableUsers = false;

          users.xin = {
            isNormalUser = true;
            hashedPasswordFile = config.sops.secrets.xin-password.path;
            shell = pkgs.fish;
            extraGroups = [
              "wheel"
              "docker"
              "ydotool"
              "scanner"
              "lp"
              "uinput"
              "input"
              "dialout"
              "plugdev"
              "networkmanager"
            ];
          };
        };
      })
    ];
  };
}
