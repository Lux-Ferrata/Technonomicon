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
    # NIXOS_OZONE_WL, so both run native on Wayland
    environment.systemPackages = with pkgs; [
      newsflash
      element-desktop
      slack
    ];
  };
}
