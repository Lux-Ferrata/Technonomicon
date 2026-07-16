{ inputs, ... }: {

  flake.nixosModules.Tn-emacs = { pkgs, ... }: {

    nixpkgs.overlays = [ inputs.doom-emacs-unstraightened.overlays.default ];

    environment.systemPackages = with pkgs; [
      (pkgs.emacsWithDoom {
        doomDir = ./Doom;
        doomLocalDir = "~/.local/share/nix-doom";

        emacs = pkgs.emacs-lucid;

        extraPackages = epkgs: [
          epkgs.treesit-grammars.with-all-grammars
        ];
      })

      # General Tooling
      claude-code
      sqlite
      gdb
      delta
      qalculate-gtk
      # AI Coding
      aider-chat
      # Accounting
      beancount
      # Markdown LSP
      marksman
      markdown-oxide
      # Export Tooling
      pandoc
      # Chart Tooling
      mermaid-cli
      drawio
      pdf2svg
      # PDF Tooling
      poppler
      # LaTeX / Typst
      texlive.combined.scheme-full
      typst
      tinymist
      # Spell Checking
      hunspell
      hunspellDicts.en_US
      # Haskell
      ghc cabal-install haskell-language-server haskellPackages.hoogle
      # Nix
      nixfmt
      nixd
      # Python
      python3 pyright ruff black
      # BQN
      cbqn
      # Bash / Shell
      shellcheck shfmt
      # Scheme & Racket
      guile racket
      # C
      clang-tools
      # Zig
      zig zls
      # Assembly & Forth
      nasm gforth
      # Verilog & VHDL
      verilator verible ghdl vhdl-ls
      # JS / TypeScript
      nodejs
      typescript-language-server
      prettier
      # DAP Debug Adapters
      lldb
      python3Packages.debugpy
      # Jupyter Notebooks
      zeromq
      python3Packages.jupyter
      python3Packages.jupyter-client
      python3Packages.nbformat
    ];
  };
}
