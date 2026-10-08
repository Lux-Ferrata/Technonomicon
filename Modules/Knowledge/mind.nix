{ inputs, ... }: {
  flake.nixosModules.Tn-mind = { pkgs, config, ... }: {
    environment.systemPackages = with pkgs; [
      obsidian
      pomodoro-gtk
      super-productivity   # tasks; syncs to Akmon over WebDAV (Tn-webdav)
    ];

    xdg.mime.defaultApplications = {
      "x-scheme-handler/obsidian" = "md.obsidian.Obsidian.desktop";
    };

    home-manager.users.xin = {
      # Obsidian's desktop entry comes from the nixpkgs package and carries no
      # Keywords, so the launcher can't find it by "notes". This user-level entry has the
      # same desktop id and shadows the system one (XDG_DATA_HOME wins) — if
      # nixpkgs renames its file again, rename this one to match or both show.
      home.file.".local/share/applications/md.obsidian.Obsidian.desktop".text = ''
        [Desktop Entry]
        Categories=Office
        Comment=Knowledge base
        Exec=obsidian %u
        Icon=obsidian
        Keywords=notes;note;markdown;vault;knowledge;zettelkasten;
        MimeType=x-scheme-handler/obsidian
        Name=Obsidian
        StartupWMClass=md.obsidian.Obsidian
        Terminal=false
        Type=Application
      '';
    };
  };
}
