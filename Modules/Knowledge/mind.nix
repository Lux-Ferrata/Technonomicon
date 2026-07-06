{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }:
  let
    pomodorolm = pkgs.callPackage ./_pomodorolm.nix {};
  in {
    environment.systemPackages = with pkgs; [
      obsidian
      taskwarrior3
      timewarrior
      pomodorolm
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };
}
