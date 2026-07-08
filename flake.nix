{
  description = "Personal system configurations.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

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
  };

  outputs = inputs@{ self, flake-parts, import-tree, nixpkgs, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    imports = [
      (import-tree ./Modules)
      (import-tree ./Hosts)
    ];

    perSystem = { pkgs, system, ... }: {
      _module.args.pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            wayscrollshot-patched =
              inputs.wayscrollshot.packages.${system}.default.overrideAttrs (old: {
                patches = (old.patches or []) ++ [
                  ./patches/wayscrollshot-max-preview-height.patch
                ];
              });
          })
        ];
      };
    };
  };
}
