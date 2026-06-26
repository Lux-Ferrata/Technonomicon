{ self, inputs, config, ... }: {
  flake.nixosConfigurations.Akmon = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./_hardware-configuration.nix
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.Tn-nix
      self.nixosModules.Tn-hyprland
      self.nixosModules.Tn-display-manager
      self.nixosModules.Tn-kanata
      self.nixosModules.Tn-web-browsers
      self.nixosModules.Tn-web-apps
      self.nixosModules.Tn-shell
      self.nixosModules.Home-xin
      ({ pkgs, config, ... }: {
        system.stateVersion = "23.11";

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
        boot.kernelModules = [ "uinput" ];
        boot.blacklistedKernelModules = [ "wacom" ];
        boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];

        services.xserver.videoDrivers = [ "nvidia" ];
        hardware.nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          open = true;
          nvidiaSettings = true;
          modesetting.enable = true;
          powerManagement.enable = false;
          powerManagement.finegrained = false;
        };
        hardware.uinput.enable = true;

        networking.hostName = "Akmon";
        networking.networkmanager.enable = true;
        time.timeZone = "America/Detroit";

        sops.secrets.xin-password.neededForUsers = true;
        sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        sops.defaultSopsFile = "${inputs.self}/_secrets.yaml";
        sops.defaultSopsFormat = "yaml";

        programs.zsh.enable = true;

        users.mutableUsers = false;
        users.users.xin = {
          isNormalUser = true;
          hashedPasswordFile = config.sops.secrets.xin-password.path;
          shell = pkgs.zsh;
          extraGroups = [ "wheel" "networkmanager" "uinput" "input" ];
        };
      })
    ];
  };
}
