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
        sops.defaultSopsFile = "${inputs.self}/_secrets.yaml";
        sops.defaultSopsFormat = "yaml";

        networking.hostName = "Kvasir";

        services.logind.settings.Login.HandleLidSwitch = "suspend";

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
