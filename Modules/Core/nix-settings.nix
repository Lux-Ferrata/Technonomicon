{ inputs, ... }: {
  flake.nixosModules.Tn-nix = { pkgs, ... }: {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.nix-index-database.nixosModules.nix-index
    ];

    services.flatpak.enable = true;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    programs.nix-index.enable = true;
    programs.nix-index-database.comma.enable = true;

    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 6d --keep 3";
      flake = "/home/xin/Projects/Technonomicon/";
    };

    nixpkgs.config.allowUnfree = true;

    virtualisation.containers.enable = true;
  };
}
