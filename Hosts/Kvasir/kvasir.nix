{ self, inputs, config, ... }: {
  flake.nixosConfigurations.Kvasir = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./_hardware-configuration.nix
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
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
        boot.loader.efi.efiSysMountPoint = "/boot";
        boot.kernelModules = [ "uinput" ];

        hardware.uinput.enable = true;

        networking.hostName = "Kvasir";
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
