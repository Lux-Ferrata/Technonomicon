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
      self.nixosModules.Tn-console-kanata
      self.nixosModules.Tn-server-usage
      self.nixosModules.Tn-server-mail
      self.nixosModules.Tn-server-alerts
      self.nixosModules.Tn-server-metrics
      self.nixosModules.Tn-server-reports
      self.nixosModules.Tn-server-review
      self.nixosModules.Tn-build-host
      self.nixosModules.Tn-forgejo
      self.nixosModules.Tn-server-web
      self.nixosModules.Tn-dev-host
      self.nixosModules.Tn-devtools
      self.nixosModules.Tn-overnight
      self.nixosModules.Tn-grimoire
      self.nixosModules.Tn-languagetool
      self.nixosModules.Tn-radicale
      self.nixosModules.Tn-calendar-push
      self.nixosModules.Tn-task-deadlines
      self.nixosModules.Tn-webdav
      self.nixosModules.Tn-paperless
      self.nixosModules.Tn-immich
      self.nixosModules.Tn-karakeep
      self.nixosModules.Tn-mail-archive
      self.nixosModules.Tn-miniflux
      self.nixosModules.Tn-atuin
      self.nixosModules.Tn-searxng
      self.nixosModules.Tn-vaultwarden
      self.nixosModules.Tn-media
      self.nixosModules.Tn-nas
      self.nixosModules.Tn-torrent
      self.nixosModules.Tn-hosting
      self.nixosModules.Tn-office
      self.nixosModules.Tn-astradraw
      self.nixosModules.Tn-openhabittracker
      self.nixosModules.Tn-hydrus
      self.nixosModules.Tn-mimir

      ({ pkgs, config, lib, ... }: {
        system.stateVersion = "23.11";

        tn.full_name     = "xin";
        tn.email_address = "git@ironshark.org";

        # scheduled jobs whose last success Tn-server-metrics tracks (seconds)
        tn.metrics.jobs = {
          bitwarden-export.maxAge   = 26 * 3600;
          paperless-exporter.maxAge = 26 * 3600;
          mail-archive-sync.maxAge  = 3600;
          overnight = { maxAge = 26 * 3600; user = true; };
        };

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
            # patchelf 0.19.2 leaves .dynamic of nvidia-smi & co in a
            # read-only segment, so they segfault in ld.so on start
            # (nixpkgs#576412, NixOS/patchelf#674). Re-patch them from the
            # untouched copies with 0.15.2, the last version that worked.
            # Drop once nixos-unstable has the fix and `nvidia-smi -L` runs
            # without this.
            package = let
              patchelf_0_15 = pkgs.patchelf.overrideAttrs (finalAttrs: _: {
                version = "0.15.2";
                src = pkgs.fetchurl {
                  url  = "https://github.com/NixOS/patchelf/releases/download/${finalAttrs.version}/patchelf-${finalAttrs.version}.tar.bz2";
                  hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
                };
              });
            in config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (o: {
              postInstall = toString (o.postInstall or null) + ''
                for f in "$bin"/origBin/*; do
                  install -Dm755 "$f" "$bin/bin/''${f##*/}"
                  ${patchelf_0_15}/bin/patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                    --set-rpath "$out/lib:$libPath" "$bin/bin/''${f##*/}"
                done
              '';
            });
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
