{
  description = "Personal system configurations.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";
    # Zotero 10.0.2 only. Unstable's 10.0.2 fails to build (2026-10-01) and
    # stable is on 9.x, which can't open a library 10 has already upgraded.
    # Drop this input once unstable builds zotero again.
    nixpkgs-zotero.url = "github:nixos/nixpkgs/b1b875982b17dabde9b4a37f3e229e74913e6db3";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    plover-flake.url = "github:openstenoproject/plover-flake";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    lazyvim.url = "github:pfassina/lazyvim-nix";
    lazyvim.inputs.nixpkgs.follows = "nixpkgs";

    wayscrollshot.url = "github:jswysnemc/wayscrollshot";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    nix-colors.url = "github:misterio77/nix-colors";

    # Open VSX / marketplace extensions that nixpkgs does not package
    # (quarto.quarto in particular). Pinned like any other input.
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nix-vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, flake-parts, import-tree, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    imports = [
      (import-tree ./Modules)
      (import-tree ./Hosts)
    ];
  };
}
