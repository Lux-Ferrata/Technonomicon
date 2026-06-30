{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      (obsidian.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          echo "StartupWMClass=electron" >> $out/share/applications/obsidian.desktop
        '';
      }))
      taskwarrior3
      timewarrior
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };
  };
}
