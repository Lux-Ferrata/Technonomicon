{ inputs, ... }: {
  flake.nixosModules.Tn-communication = { pkgs, ... }: {

    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      enable = true;
      remotes = [{
        name     = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }];
      packages = [
        { appId = "com.discordapp.Discord"; origin = "flathub"; }
      ];
      overrides."com.discordapp.Discord".Environment.TZ = "America/Phoenix";
    };

    # Element (Matrix) and Slack from nixpkgs: their wrappers honour
    # NIXOS_OZONE_WL, so both run native on Wayland. No Secret Service runs
    # here, so Element keeps its database key in the basic store (as Brave
    # does) instead of stopping at "unsupported keyring"
    environment.systemPackages = with pkgs; [
      newsflash
      (element-desktop.override { commandLineArgs = "--password-store=basic"; })
      slack
    ];
  };
}
