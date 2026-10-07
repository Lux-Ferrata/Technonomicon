{ inputs, ... }: {
  # The headless dev toolchain: compilers, language servers, formatters,
  # debuggers. On Kvasir for local work, on Akmon because remote editor
  # windows, `ak` and `rb` run there. Same nixpkgs => same store paths, so
  # editor settings that point into the store resolve on both machines.
  # Per-project libraries belong in that project's flake, not here.
  flake.nixosModules.Tn-devtools = { pkgs, pkgs-stable, ... }:
  let
    acLibrary = pkgs.callPackage ./_ac-library.nix { };
  in {

    environment.variables = {
      # NixOS does not link /include into the system profile, so ACL and
      # testlib headers are in the store but invisible to a bare
      # `g++ foo.cpp`. This puts them on the default C++ search path,
      # matching AtCoder's own judge where `#include <atcoder/all>` just works.
      CPLUS_INCLUDE_PATH = "${acLibrary}/include:${pkgs.testlib}/include/testlib";
      # rust-analyzer needs the std sources to complete into std
      RUST_SRC_PATH      = "${pkgs.rustPlatform.rustLibSrc}";
    };

    # Aider for multi-file asks, on the local chat model: 127.0.0.1:8011 is
    # Akmon's chat server there, and the online/offline proxy on Kvasir
    # (Tn-dev-host / Tn-dev-client). From stable: on unstable (2026-10-01)
    # litellm grew an exception aider refuses at import.
    home-manager.users.xin.programs.aider-chat = {
      enable   = true;
      package  = pkgs-stable.aider-chat;
      settings = {
        model                 = "openai/chat";
        openai-api-base       = "http://127.0.0.1:8011/v1";
        openai-api-key        = "local";   # llama.cpp ignores it; aider insists
        edit-format           = "diff";
        # you commit, not the model
        auto-commits          = false;
        dirty-commits         = false;
        analytics-disable     = true;
        check-update          = false;
        # the local alias isn't in litellm's model list
        show-model-warnings   = false;
        # the first request may have to wake the model
        timeout               = 300;
      };
    };

    environment.systemPackages = with pkgs; [
      claude-code
      lazygit
      delta
      sqlite
      # JS / TypeScript
      nodejs
      typescript-language-server
      prettier
      # DAP Debug Adapters
      lldb
      gdb
      python3Packages.debugpy
      # Markdown LSP
      marksman
      # Export Tooling
      pandoc
      # LaTeX / Typst
      texliveFull
      texlab # LaTeX LSP (lang.tex extra configures it; installDependencies defaults off)
      typst
      tinymist
      # Spell / Grammar Checking
      hunspell
      hunspellDicts.en_US
      harper # provides harper-ls: offline grammar + spell LSP
      ltex-ls-plus # LTeX+ server; grammar from Akmon's LanguageTool (Tn-languagetool)
      # Haskell
      ghc cabal-install haskell-language-server haskellPackages.hoogle
      # Nix
      nixfmt
      nixd
      # Python
      # 2026-10-05: coconut pinned to stable; unstable python3.12-anyio 4.14.2 tests fail (tls server_hostname)
      python3 pyright ruff black pkgs-stable.coconut
      # BQN
      cbqn
      # Bash / Shell
      shellcheck shfmt
      # Scheme & Racket
      guile racket
      # C / C++
      clang-tools   # clangd, clang-format, clang-tidy
      gcc           # cc / c++ — nothing else in this config provides a compiler
      cmake
      ninja         # cmake's default generator for anything modern
      bear          # generates compile_commands.json so clangd resolves headers
      valgrind
      # Competitive programming (AtCoder / Codeforces)
      acLibrary                      # atcoder/*.hpp headers
      ac-library                     # `expander` — inlines ACL for submission
      online-judge-tools             # `oj`: fetch samples, run tests, submit
      online-judge-template-generator # `oj-template`: boilerplate from a problem URL
      testlib                        # write generators/checkers for stress tests
      hyperfine                      # timing runs when hunting a TLE
      # Rust
      rustc cargo rustfmt clippy rust-analyzer
      # Needed by both: most C builds and any crate with a -sys dependency
      # shell out to pkg-config. Library dev deps themselves (openssl, etc.)
      # belong in a per-project flake, not here.
      pkg-config
      # Zig
      zig zls
      # Assembly & Forth. gforth from stable: on unstable (2026-10-01) its
      # bundled swig-3.0.9 fails to configure, pcre1 having been dropped.
      # Move it back to `pkgs` once unstable builds it again.
      nasm pkgs-stable.gforth
      # Verilog & VHDL
      # verilator from stable: unstable's 5.052 fails its SystemC example
      # link (2026-10-01).
      pkgs-stable.verilator verible ghdl vhdl-ls
      # Jupyter Notebooks
      zeromq
      python3Packages.jupyter
      python3Packages.jupyter-client
      python3Packages.nbformat
    ];
  };
}
