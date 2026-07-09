{ inputs, ... }: {
  flake.nixosModules.Tn-theme = { config, ... }:
  let
    nixosCfg = config;
  in {
    home-manager.users.xin = { config, ... }: {
      imports = [ inputs.nix-colors.homeManagerModules.default ];
      colorScheme = inputs.nix-colors.colorSchemes.${nixosCfg.tn.theme};
    };
  };
}
