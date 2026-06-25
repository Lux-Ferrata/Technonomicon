{ inputs, ... }: {
  flake.nixosModules.Home-xin = { ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs    = true;
      useUserPackages  = true;
      extraSpecialArgs = { inherit inputs; };
      backupFileExtension = "backup";
      users.xin = {
        imports = [
          ./_hyprland.nix
          ./_apps.nix
        ];
        home.stateVersion = "23.11";
      };
    };
  };
}
