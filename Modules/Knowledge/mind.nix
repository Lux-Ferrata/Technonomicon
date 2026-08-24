{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, config, ... }: {
    environment.systemPackages = with pkgs; [
      obsidian
      pomodoro-gtk
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "obsidian.desktop";
    };

    home-manager.users.xin = {
      # Obsidian's desktop entry comes from the nixpkgs package and carries no
      # Keywords, so wofi can't find it by "notes". This user-level entry has the
      # same desktop id and shadows the system one (XDG_DATA_HOME wins).
      home.file.".local/share/applications/obsidian.desktop".text = ''
        [Desktop Entry]
        Categories=Office
        Comment=Knowledge base
        Exec=obsidian %u
        Icon=obsidian
        Keywords=notes;note;markdown;vault;knowledge;zettelkasten;
        MimeType=x-scheme-handler/obsidian
        Name=Obsidian
        StartupWMClass=md.Obsidian
        Terminal=false
        Type=Application
      '';
    };
  };
}
