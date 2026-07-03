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
    ];
  };
}
