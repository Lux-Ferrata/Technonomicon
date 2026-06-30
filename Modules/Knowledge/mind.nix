{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      (obsidian.overrideAttrs (oldAttrs: {
        postInstall = (oldAttrs.postInstall or "") + ''
          desktop=$out/share/applications/obsidian.desktop
          [ -L "$desktop" ] && cp --remove-destination "$(readlink -f "$desktop")" "$desktop"
          echo "StartupWMClass=electron" >> "$desktop"
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
