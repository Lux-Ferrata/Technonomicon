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
      ./_disko.nix
      ./_impermanence.nix
      ./_auto-upgrade.nix

      inputs.disko.nixosModules.disko
      inputs.impermanence.nixosModules.impermanence

      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager

      self.nixosModules.Tn-user-settings
      self.nixosModules.Tn-nix
      self.nixosModules.Tn-network
      self.nixosModules.Tn-shell
      self.nixosModules.Tn-server
      self.nixosModules.Tn-server-nvim
      self.nixosModules.Tn-server-mail
      self.nixosModules.Tn-build-host
      self.nixosModules.Tn-forgejo
      self.nixosModules.Tn-dev-host
      self.nixosModules.Tn-devtools
      self.nixosModules.Tn-overnight

      ({ pkgs, config, lib, ... }: {
        system.stateVersion = "23.11";

        tn.full_name     = "xin";
        tn.email_address = "git@ironshark.org";

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        boot = {
          initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
          kernelPackages = pkgs.linuxPackages;
        };

        # headless: the driver is only here for compute (CUDA containers etc.);
        # videoDrivers is how NixOS loads it, it doesn't start X
        services.xserver.videoDrivers = [ "nvidia" ];

        # RTX 5080 (Blackwell): build CUDA packages for sm_120 only, not
        # every architecture nixpkgs supports
        nixpkgs.config.cudaCapabilities = [ "12.0" ];

        hardware = {
          nvidia-container-toolkit.enable = true;
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.stable;
            open = true;
            nvidiaSettings = false;
            modesetting.enable = true;
            powerManagement.enable = false;
            powerManagement.finegrained = false;
          };
        };

        virtualisation.docker.enable = true;

        sops.secrets.xin-password.neededForUsers = true;
        sops.age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
        sops.defaultSopsFile = ../../_secrets.yaml;
        sops.defaultSopsFormat = "yaml";

        networking.hostName = "Akmon";

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
              "networkmanager"
            ];
          };
        };
      })
    ];
  };
}
