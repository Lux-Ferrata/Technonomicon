{ inputs, ... }: {
  flake.nixosModules.Tn-kanata = { pkgs, ... }: {

    services.kanata = {
      enable = true;
      package = pkgs.kanata-with-cmd;
      keyboards.colmacs.configFile = ./_kanata.kbd;
    };
  };
}
