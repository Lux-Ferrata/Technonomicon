{ self, inputs, config, ... }: {
  flake.nixosConfigurations.Akmon = inputs.nixpkgs.lib.nixosSystem {
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

      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager

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
      self.nixosModules.Tn-sound
      self.nixosModules.Tn-shell
      self.nixosModules.Tn-pdf
      self.nixosModules.Tn-games
      self.nixosModules.Tn-learning
      self.nixosModules.Tn-mind
      self.nixosModules.Tn-art
      self.nixosModules.Tn-utf
      self.nixosModules.Tn-virtualization

      ({ pkgs, config, ... }: {
        system.stateVersion = "23.11";

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        boot = {
          initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
          kernelModules = [ "uinput" ];
          blacklistedKernelModules = [ "wacom" ];
          kernelPackages = pkgs.linuxPackages;
          kernelParams = [
            "nvidia-drm.modeset=1"
            "nvidia-drm.fbdev=1"
          ];
        };

        services.xserver.videoDrivers = [ "nvidia" ];

        hardware = {
          nvidia-container-toolkit.enable = true;
          uinput.enable = true;
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            open = true;
            nvidiaSettings = true;
            modesetting.enable = true;
            powerManagement.enable = false;
            powerManagement.finegrained = false;
          };
          opentabletdriver = {
            enable = true;
            daemon.enable = true;
          };
        };

        sops.secrets.xin-password.neededForUsers = true;
        sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        sops.defaultSopsFile = "${inputs.self}/_secrets.yaml";
        sops.defaultSopsFormat = "yaml";

        networking.hostName = "Akmon";

        environment.sessionVariables = {
          LIBVA_DRIVER_NAME         = "nvidia";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          NVD_BACKEND               = "direct";
        };

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
            shell = pkgs.xonsh;
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
