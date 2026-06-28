{ inputs, ... }: {
  flake.nixosModules.Tn-art = { pkgs, config, ... }:
    let
      allusion = pkgs.callPackage (import ./Allusion/_allusion.nix) {};
    in {

      environment.systemPackages = with pkgs; [
        openscad
        openscad-lsp
        graphviz
        cura-appimage
        obs-studio
        vlc
        inkscape-with-extensions
        gimp-with-plugins
        krita
        blender
        pureref
        allusion
        yt-dlp
        ffmpeg
        wl-color-picker
        pinta
      ];

      home-manager.users.xin.home.file.".config/OpenSCAD/OpenSCAD.conf".text = ''
        [General]
        recentFileList=@Invalid()

        [3dview]
        colorscheme=DeepOcean

        [design]
        autoReload=true

        [view]
        hide3DViewToolbar=true
        hideConsole=true
        hideCustomizer=true
        hideEditor=true
        hideEditorToolbar=true
        hideErrorLog=true
        orthogonalProjection=true
        showAxes=true
        showScaleProportional=true
      '';
    };
}
