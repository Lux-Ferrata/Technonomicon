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

    sops.secrets.habitica-api-token = { owner = "xin"; };
    sops.secrets.habitica-user-id   = { owner = "xin"; };
    sops.secrets.habitica-task-id   = { owner = "xin"; };


    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };
}
