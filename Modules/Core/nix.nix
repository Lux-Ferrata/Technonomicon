{ inputs, ... }: {
  flake.nixosModules.Tn-nix = { pkgs, ... }: {
    programs.nh = {
      enable    = true;
      flake     = "/home/xin/Projects/Technonomicon";
      clean.enable    = true;
      clean.automatic = true;
    };

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
    };

    nixpkgs.config.allowUnfree = true;
  };
}
