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
      self.nixosModules.Tn-gdrive
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
      self.nixosModules.Tn-vikunja
      self.nixosModules.Tn-art
      self.nixosModules.Tn-utf
      self.nixosModules.Tn-virtualization
      self.nixosModules.Tn-build-client
      self.nixosModules.Tn-dev-client
      self.nixosModules.Tn-devtools

      ({ pkgs, config, ... }: {
        system.stateVersion = "23.11";

        tn.full_name          = "xin";
        tn.email_address      = "git@ironshark.org";
        tn.theme              = "tn";
        tn.primary_font       = "Atkinson Hyperlegible Mono Liga";
        tn.ui_font            = "Atkinson Hyperlegible Next";
        tn.scale              = 1;
        tn.quick_app_bindings = {};
        # tn.wallpaper_path  = "/home/xin/Projects/Technonomicon/.wallpapers/wallpaper.png";

        boot.kernelModules = [ "uinput" ];
        boot.kernelPackages = pkgs.linuxPackages;
        boot.blacklistedKernelModules = [ "wacom" ];

        # The T480s Thunderbolt controller (NHI 8086:15bf) is stuck in safe
        # mode (old NVM firmware), so its driver can only fail the ICM
        # handshake on resume -- which looks to be what hung 3 of 4 suspends
        # (Oct 2026). The module can't be blacklisted: typec (USB-C) depends
        # on it and loads it anyway. So let it bind, then release the
        # controller at once. The port's USB 3.1 controller and charging are
        # separate devices. Updating the NVM (fwupd) is the real fix, and
        # needs this rule off.
        services.udev.extraRules = ''
          ACTION=="bind", SUBSYSTEM=="pci", DRIVER=="thunderbolt", ATTR{vendor}=="0x8086", ATTR{device}=="0x15bf", RUN+="${pkgs.runtimeShell} -c 'echo %k > /sys/bus/pci/drivers/thunderbolt/unbind'"
        '';
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

        # Tasks: a local Vikunja (Tn-vikunja, backed up to Akmon). Habits:
        # OpenHabitTracker (Tn-mind, syncs through Akmon).

        services.logind.settings.Login.HandleLidSwitch = "suspend";

        # tailnet client: reaches and deploys to Akmon (ssh xin@akmon)
        services.tailscale = {
          enable        = true;
          # lets xin's own session receive Taildrop files (and run `tailscale file`)
          extraSetFlags = [ "--operator=xin" ];
        };

        # Taildrop: phone's share sheet -> "Tailscale" -> Kvasir lands files in
        # ~/Downloads; `send <files>` goes the other way
        home-manager.users.xin = {
          systemd.user.services.taildrop-receive = {
            Unit.Description = "Move incoming Taildrop files into ~/Downloads";
            Service = {
              ExecStart  = "${pkgs.tailscale}/bin/tailscale file get --loop --conflict=rename %h/Downloads";
              Restart    = "always";
              RestartSec = 10;
            };
            Install.WantedBy = [ "default.target" ];
          };
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
              "networkmanager"
            ];
          };
        };
      })
    ];
  };
}
