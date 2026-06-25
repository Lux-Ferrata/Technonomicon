{ inputs, ... }: {
  flake.nixosModules.Tn-shell = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      ghostty
      neovim
      claude-code
      gitFull
      git-lfs
    ];
  };
}
