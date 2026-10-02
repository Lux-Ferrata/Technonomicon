{ inputs, ... }: {
  flake.nixosModules.Tn-games = { pkgs, ... }:
    let
      weiqi-hub = pkgs.callPackage (import ./WeiqiHub/_weiqi-hub.nix) {};
    in {

    environment.systemPackages = with pkgs; [
      xivlauncher
      hyperspeedcube
      exercism
      weiqi-hub

      # nixpkgs' hyperspeedcube ships no .desktop file.
      (makeDesktopItem {
        name        = "hyperspeedcube";
        desktopName = "Cube";
        exec        = "${hyperspeedcube}/bin/hyperspeedcube";
        terminal    = false;
        keywords    = [ "cube" "rubik" "puzzle" "hyperspeedcube" "4d" ];
        categories  = [ "Game" "LogicGame" ];
      })
    ];
  };
}
