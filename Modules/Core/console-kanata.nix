{ inputs, ... }: {
  # Emergency keyboard for a headless box: when something has to be typed at
  # Akmon's own console (a password, a rescue shell), it types the same way as
  # Kvasir does instead of raw QWERTY. Grabs whatever keyboard gets plugged
  # in. Layout and escape hatch are in _kanata-console.kbd.
  flake.nixosModules.Tn-console-kanata = { pkgs, ... }: {
    services.kanata = {
      enable  = true;
      package = pkgs.kanata;          # no cmd actions on a server
      keyboards.console = {
        # devices = [ ] (the default): every keyboard that shows up
        config      = builtins.readFile ./_kanata-console.kbd;
        extraDefCfg = ''
          process-unmapped-keys yes
          concurrent-tap-hold yes
        '';
      };
    };

    # what the hardware types if kanata isn't running
    console.keyMap = "us";
  };
}
