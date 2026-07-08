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
      overrides."com.discordapp.Discord".Context.filesystems = [
        "/etc/localtime:ro"
        "/etc/zoneinfo:ro"
      ];
    };

    environment.systemPackages = with pkgs; [
      newsflash
    ];
  };
}
