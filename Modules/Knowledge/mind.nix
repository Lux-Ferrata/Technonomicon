{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }:
  let
    tomatych = pkgs.callPackage ./_tomatych.nix {};
  in {
    environment.systemPackages = with pkgs; [
      obsidian
      taskwarrior3
      timewarrior
      tomatych
    ];


    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };
}
