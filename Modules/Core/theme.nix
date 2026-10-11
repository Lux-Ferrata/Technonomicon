{ inputs, ... }: {
  # tn.theme picks the base16 scheme the desktop is drawn in: "tn" is the
  # repo's own palette (_palette.nix, shared with VSCodium and nvim),
  # anything else a nix-colors scheme by name.
  flake.nixosModules.Tn-theme = { config, ... }:
  let
    nixosCfg = config;
  in {
    home-manager.users.xin = { config, ... }: {
      imports = [ inputs.nix-colors.homeManagerModules.default ];
      colorScheme =
        if nixosCfg.tn.theme == "tn" then {
          slug    = "tn";
          name    = "Technonomicon";
          author  = "xin";
          variant = "dark";
          palette = (import ./_palette.nix).base16;
        }
        else inputs.nix-colors.colorSchemes.${nixosCfg.tn.theme};
    };
  };
}
