{ inputs, ... }: {

  flake.nixosModules.Tn-neovim = { pkgs, pkgs-stable, ... }:
  let
    openVsx   = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.open-vsx;
    vscodeMkt = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;

    # nixpkgs' `ac-library` installs only bin/expander -- it ships none of the
    # atcoder/*.hpp headers, so it cannot actually be #included. This packages
    # the headers themselves; `expander` from nixpkgs still inlines them into a
    # single file for submission.
    acLibrary = pkgs.stdenvNoCC.mkDerivation {
      pname   = "ac-library-headers";
      version = "1.6";
      src = pkgs.fetchFromGitHub {
        owner  = "atcoder";
        repo   = "ac-library";
        rev    = "v1.6";
        hash   = "sha256-zV2G9Ur2v8elGVKuO9w7ampaB13wDod9qzo7+QXq6G4=";
      };
      dontBuild = true;
      installPhase = ''
        mkdir -p $out/include
        cp -r atcoder $out/include/
      '';
      meta.description = "Official AtCoder Library, headers only";
    };

    mcpy = pkgs.python3Packages.buildPythonPackage rec {
      pname = "mcpy";
      version = "2.0.0";
      pyproject = true;
      build-system = [ pkgs.python3Packages.setuptools ];
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/c1/fb/b686ec3bb91b8d1f08092cabcbaedf78d6350cb9debe2dbbbbdde07c185d/mcpy-${version}.tar.gz";
        sha256 = "017sv0bjwqchl28nz7shfrsl72251aqqr8xb2d3qgxr6swv8ghv9";
      };
      doCheck = false;
    };

    previewImage = pkgs.writeShellScriptBin "preview-image" ''
      path="$1"
      [ -z "$path" ] && exit 1
      [[ "$path" != /* ]] && path="$(pwd)/$path"
      ${pkgs.imv}/bin/imv "$path" & disown
    '';

    openInGhostty = pkgs.writeShellScriptBin "open-in-ghostty" ''
      file="$1"
      if [ -z "$file" ] || [ "$file" = "[scratch]" ]; then
        dir="$HOME"
      else
        dir=$(dirname "$(realpath "$file")")
      fi
      ghostty --working-directory "$dir" &
      disown
    '';

    openInObsidian = pkgs.writeShellScriptBin "open-in-obsidian" ''
      if [ -z "$1" ] || [ "$1" = "[scratch]" ]; then
        exit 1
      fi
      FILE_PATH=$(realpath "$1")
      ENCODED_PATH=$(${pkgs.python3}/bin/python3 -c \
        "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" \
        "$FILE_PATH")
      ${pkgs.xdg-utils}/bin/xdg-open "obsidian://open?path=$ENCODED_PATH"
      # This Hyprland build is Lua-only: `hyprctl dispatch` is rejected, so
      # dispatches must go through `hyprctl eval "hl.dispatch(...)"`.
      hyprctl eval "hl.dispatch(hl.dsp.focus({window='class:^md.obsidian.Obsidian$'}))"
    '';
  in {

    # NixOS does not link /include into the system profile, so ACL and testlib
    # headers are in the store but invisible to a bare `g++ foo.cpp`. This puts
    # them on the default C++ search path, matching AtCoder's own judge where
    # `#include <atcoder/all>` just works.
    environment.variables.CPLUS_INCLUDE_PATH =
      "${acLibrary}/include:${pkgs.testlib}/include/testlib";

    environment.systemPackages = with pkgs; [
      previewImage
      openInGhostty
      openInObsidian
      imv
      lazygit
      ghostty
      # JS / TypeScript
      nodejs
      typescript-language-server
      prettier
      # File Management
      yazi
      # Git
      delta
      # DAP Debug Adapters
      lldb
      python3Packages.debugpy
      # Accounting
      beancount
      # AI Coding. From stable: on unstable (2026-10-01) litellm grew an
      # exception aider refuses at import, so it fails its tests and crashes.
      pkgs-stable.aider-chat
      # Markdown LSP
      marksman
      # General Tooling
      qalculate-gtk
      libqalculate # provides the `qalc` CLI
      claude-code
      sqlite
      gdb
      # Export Tooling
      pandoc
      # Chart Tooling
      mermaid-cli
      drawio
      pdf2svg
      # PDF Tooling
      poppler
      # LaTeX / Typst
      texliveFull
      texlab # LaTeX LSP (lang.tex extra configures it; installDependencies defaults off)
      typst
      tinymist
      # Spell / Grammar Checking
      hunspell
      hunspellDicts.en_US
      harper # provides harper-ls: offline grammar + spell LSP
      # Haskell
      ghc cabal-install haskell-language-server haskellPackages.hoogle
      # Nix
      nixfmt
      nixd
      # Python
      python3 pyright ruff black coconut
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
      python3Packages.pynvim
      python3Packages.jupyter-client
      python3Packages.nbformat
      python3Packages.cairosvg
      mcpy
      # image.nvim — provides the magick luarock via nix instead of luarocks
      luajitPackages.magick
    ];

    home-manager.users.xin.programs.vscodium = {
      enable = true;
      profiles.default = {
        extensions = (with openVsx; [
          # Not packaged in nixpkgs. Deliberately left without a `quarto.path`
          # so the blog flake's direnv-provided CLI is the one it picks up.
          quarto.quarto
        ]) ++ [
          # Harpoon-style pinned files (MIT). Published only to the MS
          # marketplace, so it comes from that index rather than Open VSX.
          vscodeMkt.tobias-z.vscode-harpoon
        ] ++ (with pkgs.vscode-extensions; [
          arcticicestudio.nord-visual-studio-code
          vscodevim.vim
          # Every extension below is MIT/BSD0 and Open-VSX-clean. Pylance is
          # deliberately absent: it is unfree and refuses to run on VSCodium.
          mkhl.direnv
          jnoortheen.nix-ide
          ms-pyright.pyright
          ms-python.python
          ms-python.black-formatter
          charliermarsh.ruff
          mkhl.shfmt
          ms-toolsai.jupyter
          haskell.haskell
          llvm-vs-code-extensions.vscode-clangd
          ziglang.vscode-zig
          rust-lang.rust-analyzer
          # CodeLLDB is the debug adapter for C/C++/Rust. ms-vscode.cpptools
          # is unfree and licensed to official VS Code builds only.
          vadimcn.vscode-lldb
          ms-vscode.cmake-tools
          james-yu.latex-workshop
          # Spell checker (GPL-3.0). Limited to comments in code, see cSpell.*
          streetsidesoftware.code-spell-checker
        ]);

        keybindings = [
          # Normal mode only, so ctrl+space keeps triggering completion while
          # actually typing. User keybindings are matched after the defaults,
          # so this wins in normal mode and the default wins in insert mode.
          {
            key     = "ctrl+space";
            command = "workbench.action.showCommands";
            when    = "editorTextFocus && vim.mode == 'Normal'";
          }
          # F4 toggles the bottom terminal from anywhere, and back to the editor
          { key = "f4"; command = "workbench.action.terminal.toggleTerminal"; }
        ]
        # Alt+1..5 jumps to harpoon slot N from any mode, terminal included
        ++ map (n: {
          key     = "alt+${toString n}";
          command = "vscode-harpoon.gotoEditor${toString n}";
        }) [ 1 2 3 4 5 ];

        userSettings = {
          "workbench.colorTheme"           = "Nord";
          # Nord's selected row in dropdowns (quick fix, completion, command
          # palette, context menus) is a barely-lighter grey. Make it solid
          # frost (nord8) with dark text (nord0) so the active item is obvious.
          "workbench.colorCustomizations" = let
            sel = { bg = "#88C0D0"; fg = "#2E3440"; };
          in {
            "editorActionList.focusBackground"      = sel.bg;
            "editorActionList.focusForeground"      = sel.fg;
            "editorSuggestWidget.selectedBackground" = sel.bg;
            "editorSuggestWidget.selectedForeground" = sel.fg;
            "editorSuggestWidget.selectedIconForeground" = sel.fg;
            "editorSuggestWidget.focusHighlightForeground" = sel.fg;
            "quickInputList.focusBackground"        = sel.bg;
            "quickInputList.focusForeground"        = sel.fg;
            "quickInputList.focusIconForeground"    = sel.fg;
            "list.activeSelectionBackground"        = sel.bg;
            "list.activeSelectionForeground"        = sel.fg;
            "list.activeSelectionIconForeground"    = sel.fg;
            "list.focusHighlightForeground"         = sel.fg;
            "menu.selectionBackground"              = sel.bg;
            "menu.selectionForeground"              = sel.fg;
          };
          "editor.fontFamily"              = "'JetBrains Mono', monospace";
          "editor.fontSize"                = 14;
          "editor.lineNumbers"             = "relative";
          "editor.minimap.enabled"         = false;

          # Chrome removal: no tab bar, no panel-ish furniture.
          "workbench.editor.showTabs"            = "none";
          "workbench.activityBar.location"       = "hidden";
          "workbench.layoutControl.enabled"      = false;
          "window.commandCenter"                 = false;
          # With the menu bar, layout control and command center all gone the
          # custom title bar is an empty strip. Hyprland draws no server-side
          # titlebar, so "native" reclaims the row entirely.
          "window.titleBarStyle"                 = "native";
          # Chrome that has no vim equivalent and is on by default.
          "editor.stickyScroll.enabled"          = false;
          "editor.lightbulb.enabled"             = "off";
          "workbench.editor.editorActionsLocation" = "hidden";
          "workbench.startupEditor"              = "none";
          "breadcrumbs.enabled"                  = false;
          "window.menuBarVisibility"             = "hidden";
          # Status bar deliberately kept: it is where VSCodeVim renders the
          # current mode. Set "workbench.statusBar.visible" = false to drop it.

          # Match the nvim side of the house.
          "files.trimTrailingWhitespace" = true;
          "files.autoSave"               = "onFocusChange";

          # nix-ide defaults to the `nil` server, which is not installed here.
          # Point it at the nixd/nixfmt pair this repo already ships.
          "nix.enableLanguageServer" = true;
          "nix.serverPath"           = "nixd";
          "nix.formatterPath"        = "nixfmt";

          # Both of these extensions download their own server binary unless
          # pointed at one; use the nixpkgs builds already on PATH.
          "clangd.path"               = "clangd";
          # With no compile_commands.json, clangd falls back to a standard old
          # enough that <ranges> and views fail to parse. bits/stdc++.h and
          # ext/pb_ds already resolve without help -- the nixpkgs clang-tools
          # build bakes in gcc's libstdc++ include paths.
          "clangd.fallbackFlags" = [
            "-std=gnu++23"
            "-I${acLibrary}/include"
          ];
          "rust-analyzer.server.path" = "rust-analyzer";
          # rust-analyzer needs the std sources to complete into std.
          "rust-analyzer.server.extraEnv" = {
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };

          # LaTeX Workshop. texliveFull already supplies every binary it wants
          # (latexmk, all engines, biber, chktex, latexindent), so only the
          # non-default choices are set here.
          "latex-workshop.latex.autoBuild.run"     = "onSave";
          "latex-workshop.latex.autoClean.run"     = "onSucceeded";
          "latex-workshop.latex.outDir"            = "%DIR%/build";
          "latex-workshop.linting.chktex.enabled"  = true;
          "latex-workshop.view.pdf.viewer"         = "tab";

          # Quarto has no packaged extension; .qmd is markdown plus fenced
          # cells, so this gets highlighting without one.
          "files.associations" = { "*.qmd" = "markdown"; };

          # Formatters are all already on PATH via systemPackages above.
          "editor.formatOnSave"      = true;
          "editor.wordWrap"          = "on";
          "editor.renderLineHighlight" = "all";
          "terminal.integrated.fontFamily" = "'JetBrains Mono', monospace";
          # let F4 and the harpoon jumps through instead of sending them to fish
          "terminal.integrated.commandsToSkipShell" = [
            "workbench.action.terminal.toggleTerminal"
          ] ++ map (n: "vscode-harpoon.gotoEditor${toString n}") [ 1 2 3 4 5 ];
          "telemetry.telemetryLevel" = "off";

          # ms-python.python would otherwise try to start Pylance; the
          # standalone pyright extension provides the language server.
          "python.languageServer" = "None";

          # vim. Defaults that differ from real vim / the nvim config:
          # useSystemClipboard matches `set clipboard=unnamed`, hlsearch and
          # highlightedyank match LazyVim. smartRelativeLine is left off on
          # purpose: the nvim config sets relativenumber unconditionally.
          "vim.leader"     = "<space>";
          "vim.easymotion" = true;
          "vim.useSystemClipboard"        = true;
          "vim.hlsearch"                  = true;
          "vim.highlightedyank.enable"    = true;
          # Keep the active line centred: more surrounding lines than half a
          # screen pins the cursor to the middle (like scrolloff=999), and
          # scrolling past the last line lets that hold at the end of a file.
          # Applies to mouse clicks too, not just keyboard moves.
          "editor.cursorSurroundingLines"      = 999;
          "editor.cursorSurroundingLinesStyle" = "all";
          "editor.scrollBeyondLastLine"        = true;
          "editor.renderWhitespace"            = "all";

          # cSpell checks code, strings and identifiers by default. In code it
          # is narrowed to comments only; prose files (markdown, latex, typst,
          # plaintext, ...) have no languageSettings entry and are checked whole.
          "cSpell.patterns" = [
            { name = "hash-comment";   pattern = "/#.*/g"; }
            { name = "slash-comment";  pattern = ''/\/\/.*/g''; }
            { name = "c-block-comment";  pattern = ''/\/\*[\s\S]*?\*\//g''; }
            { name = "dash-comment";   pattern = "/--.*/g"; }
            { name = "hs-block-comment"; pattern = ''/\{-[\s\S]*?-\}/g''; }
          ];
          "cSpell.languageSettings" = [
            { languageId = [ "python" "shellscript" "fish" "yaml" "toml" "r" "julia" "dockerfile" "makefile" "cmake" ];
              includeRegExpList = [ "hash-comment" ]; }
            { languageId = [ "nix" ];
              includeRegExpList = [ "hash-comment" "c-block-comment" ]; }
            { languageId = [ "c" "cpp" "rust" "zig" "javascript" "typescript" "javascriptreact" "typescriptreact" "java" "go" "jsonc" ];
              includeRegExpList = [ "slash-comment" "c-block-comment" ]; }
            { languageId = [ "haskell" "lua" "sql" ];
              includeRegExpList = [ "dash-comment" "hs-block-comment" ]; }
          ];
          # VSCodeVim's iskeyword lists word *separators* (the inverse of
          # vim's). This is its default plus `_`, so w/e/b/dw stop at
          # underscores, same as the nvim config.
          "vim.iskeyword" = ''/\()"':,.;<>~!@#$%^&*|+=[]{}`?-_'';
          # Same for non-vim word ops: double-click, ctrl+arrow, ctrl+backspace
          "editor.wordSeparators" = ''/\()"':,.;<>~!@#$%^&*|+=[]{}`?-_'';
          # LazyVim binds `s` to flash.nvim. easymotion's n-char search is the
          # closest analogue: press s, type as many characters as you like,
          # Enter, pick a label.
          "vim.normalModeKeyBindingsNonRecursive" = [
            { before = [ "s" ]; after = [ "<leader>" "<leader>" "/" ]; }
            # Harpoon, on LazyVim's harpoon-extra keys: H pins the file,
            # h picks from the pins, 1-5 jump straight to a slot, m edits
            # the pin list (reorder/delete lines, save).
            { before = [ "<leader>" "H" ]; commands = [ "vscode-harpoon.addEditor" ]; }
            { before = [ "<leader>" "h" ]; commands = [ "vscode-harpoon.editorQuickPick" ]; }
            { before = [ "<leader>" "m" ]; commands = [ "vscode-harpoon.editEditors" ]; }
          ] ++ map (n: {
            before   = [ "<leader>" (toString n) ];
            commands = [ "vscode-harpoon.gotoEditor${toString n}" ];
          }) [ 1 2 3 4 5 ];
          "vim.visualModeKeyBindingsNonRecursive" = [
            { before = [ "s" ]; after = [ "<leader>" "<leader>" "/" ]; }
          ];
        };
      };
    };

    # `eo` is a plain $PATH binary, so putting it here makes VSCodium the
    # default target while still letting a project dev shell win by
    # prepending its own.
    home-manager.users.xin.home.packages = [
      (pkgs.writeShellScriptBin "eo" ''
        if [ "$#" -eq 0 ]; then
          exec ${pkgs.vscodium}/bin/codium .
        fi
        exec ${pkgs.vscodium}/bin/codium "$@"
      '')
    ];

    home-manager.users.xin.home.file = {
      ".config/yazi/yazi.toml".text = ''
        [mgr]
        show_hidden    = false
        sort_by        = "natural"
        sort_dir_first = true
        linemode       = "mtime"
        scrolloff      = 5

        # Enter on text/code opens VSCodium (detached); `O` offers nvim too
        [opener]
        edit = [
          { run = 'codium "$@"', orphan = true, desc = "VSCodium" },
          { run = 'nvim "$@"', block = true, desc = "Neovim" },
        ]
      '';

      ".config/yazi/keymap.toml".text = ''
        [[mgr.prepend_keymap]]
        on   = [ "d" ]
        run  = "shell 'trash-put \"$@\"' --confirm"
        desc = "Move to trash"

        [[mgr.prepend_keymap]]
        on   = [ "D" ]
        run  = "remove --permanently"
        desc = "Permanently delete"

        [[mgr.prepend_keymap]]
        on   = [ "e" ]
        run  = "shell 'nvim \"$@\"' --block"
        desc = "Edit in Neovim"

        [[mgr.prepend_keymap]]
        on   = [ "C" ]
        run  = "shell 'codium .' --orphan"
        desc = "Open directory in VSCodium"

        # t/T match the shell's zoxide `t`; new tab moves to Ctrl-t
        [[mgr.prepend_keymap]]
        on   = [ "t" ]
        run  = "plugin zoxide"
        desc = "Jump via zoxide"

        [[mgr.prepend_keymap]]
        on   = [ "T" ]
        run  = "plugin fzf"
        desc = "Jump via fzf"

        [[mgr.prepend_keymap]]
        on   = [ "<C-t>" ]
        run  = "tab_create --current"
        desc = "New tab"

        [[mgr.prepend_keymap]]
        on   = [ "g", "p" ]
        run  = "cd ~/Projects"
        desc = "Go to Projects"

        [[mgr.prepend_keymap]]
        on   = [ "g", "t" ]
        run  = "cd ~/Projects/Technonomicon"
        desc = "Go to Technonomicon"

        [[mgr.prepend_keymap]]
        on   = [ "g", "r" ]
        run  = "cd ~/Grimoire"
        desc = "Go to Grimoire"
      '';
    };

    home-manager.users.xin = {
      imports = [ inputs.lazyvim.homeManagerModules.default ];

      programs.neovim.extraLuaPackages = ps: [ ps.magick ];

      programs.lazyvim = {
        enable = true;

        extras = {
          lang.nix              = { enable = true; };
          lang.python           = { enable = true; installDependencies = false; };
          lang.typescript       = { enable = true; installDependencies = false; };
          lang.tex              = { enable = true; };
          coding.luasnip        = { enable = true; };
        };

        plugins = {

          undotree = ''
            return {
              "mbbill/undotree",
              keys = {
                { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "Toggle Undo Tree" },
              },
            }
          '';

          colorscheme = ''
            return {
              "shaunsingh/nord.nvim",
              priority = 1000,
              config = function()
                vim.g.nord_contrast               = true
                vim.g.nord_borders                = false
                vim.g.nord_disable_background     = false
                vim.g.nord_cursorline_transparent  = false
                vim.g.nord_italic                 = true
                vim.g.nord_bold                   = false
                require("nord").set()
              end,
            }
          '';

          obsidian = ''
            return {
              "epwalsh/obsidian.nvim",
              version = "*",
              lazy = true,
              ft = "markdown",
              dependencies = { "nvim-lua/plenary.nvim" },
              opts = {
                workspaces = {
                  { name = "Grimoire", path = "~/Grimoire" },
                },
                follow_url_func = function(url)
                  vim.fn.jobstart({ "xdg-open", url })
                end,
              },
            }
          '';

          anki = ''
            return {
              "rareitems/anki.nvim",
              dependencies = { "nvim-lua/plenary.nvim" },
              lazy = false,
              opts = {
                tex_support = false,
                models = {
                  ["Basic"]                     = "Default",
                  ["Basic (and reversed card)"] = "Default",
                },
              },
            }
          '';

          lsp = ''
            return {
              "neovim/nvim-lspconfig",
              opts = {
                servers = {
                  hls       = {},
                  clangd    = {},
                  zls       = {},
                  marksman  = {},
                  texlab    = {},
                  harper_ls = {},
                },
              },
            }
          '';

          image = ''
            return {
              "3rd/image.nvim",
              build = false,
              opts = {
                backend    = "kitty",
                max_width  = 100,
                max_height = 12,
                rocks      = { enabled = false },
              },
            }
          '';

          molten = ''
            return {
              "benlubas/molten-nvim",
              build = ":UpdateRemotePlugins",
              init = function()
                vim.g.molten_image_provider        = "image.nvim"
                vim.g.molten_output_win_max_height = 20
                vim.g.molten_auto_open_output      = false
                vim.g.molten_wrap_output           = true
              end,
              keys = {
                { "<leader>mi", ":MoltenInit<CR>",                                 desc = "Initialize Molten" },
                { "<leader>me", ":MoltenEvaluateOperator<CR>",                     desc = "Evaluate operator" },
                { "<leader>ml", ":MoltenEvaluateLine<CR>",                         desc = "Evaluate line" },
                { "<leader>mv", ":<C-u>MoltenEvaluateVisual<CR>", mode = "v",      desc = "Evaluate visual" },
                { "<leader>mo", ":MoltenEnterOutput<CR>",                          desc = "Enter output" },
                { "<leader>mh", ":MoltenHideOutput<CR>",                           desc = "Hide output" },
              },
            }
          '';

          quarto = ''
            return {
              {
                "quarto-dev/quarto-nvim",
                dependencies = { "jmbuhr/otter.nvim", "nvim-treesitter/nvim-treesitter" },
                opts = {
                  lspFeatures = {
                    languages = { "python", "julia", "r", "lua", "bash" },
                  },
                },
              },
              {
                "jmbuhr/otter.nvim",
                opts = {},
              },
            }
          '';

          imgclip = ''
            return {
              "HakonHarnes/img-clip.nvim",
              event = "VeryLazy",
              opts = {
                default = {
                  embed_image_as_base64 = false,
                  prompt_for_file_name  = false,
                  drag_and_drop         = { insert_mode = true },
                },
              },
              keys = {
                { "<leader>P", "<cmd>PasteImage<cr>", desc = "Paste image" },
              },
            }
          '';

          nabla = ''
            return {
              "jbyuki/nabla.nvim",
              keys = {
                { "<leader>np", function() require("nabla").popup() end,       desc = "Preview equation" },
                { "<leader>nt", function() require("nabla").toggle_virt() end, desc = "Toggle math virtual text" },
              },
            }
          '';

          bibtex = ''
            return {
              "nvim-telescope/telescope-bibtex.nvim",
              dependencies = { "nvim-telescope/telescope.nvim" },
              config = function()
                require("telescope").load_extension("bibtex")
              end,
              keys = {
                { "<leader>cb", "<cmd>Telescope bibtex<cr>", desc = "BibTeX references" },
              },
            }
          '';
        };

        config = {
          options = ''
            vim.opt.relativenumber = true
            vim.opt.cursorline     = true
            vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
            vim.opt.wrap      = true
            vim.opt.linebreak = true
          '';

          autocmds = ''
            -- `_` separates words, so w/e/b/dw stop at underscores (matches
            -- the VSCodium vim.iskeyword setting). Done per-FileType rather
            -- than in options, because ftplugins can reset iskeyword wholesale.
            vim.opt.iskeyword:remove("_")
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "*",
              callback = function()
                vim.opt_local.iskeyword:remove("_")
              end,
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
              pattern = "*",
              callback = function()
                local pos = vim.api.nvim_win_get_cursor(0)
                vim.cmd([[%s/\s\+$//e]])
                vim.api.nvim_win_set_cursor(0, pos)
              end,
            })

            -- Autosave on every switch to normal mode. Guarded so it never
            -- errors on scratch/terminal/nameless/readonly buffers (E32).
            vim.api.nvim_create_autocmd("InsertLeave", {
              pattern = "*",
              callback = function()
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].buftype ~= "" then return end
                if vim.api.nvim_buf_get_name(buf) == "" then return end
                if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return end
                if vim.bo[buf].modified then vim.cmd("silent! write") end
              end,
            })

            vim.api.nvim_create_autocmd("FileType", {
              pattern = "markdown",
              callback = function()
                vim.keymap.set("i", "<CR>", function()
                  local line = vim.api.nvim_get_current_line()
                  local col = vim.api.nvim_win_get_cursor(0)[2]
                  if col < #line then return "<CR>" end

                  -- Empty checkbox item: clear marker and stay on line
                  if line:match("^%s*%- %[.%]%s*$") then return "<C-u>" end
                  -- Checkbox with content: continue with unchecked box
                  local indent = line:match("^(%s*)%- %[.%] ")
                  if indent then return "<CR>" .. indent .. "- [ ] " end

                  -- Empty bullet: clear marker
                  if line:match("^%s*%-%s*$") then return "<C-u>" end
                  -- Bullet with content: continue list
                  indent = line:match("^(%s*)%- ")
                  if indent then return "<CR>" .. indent .. "- " end

                  return "<CR>"
                end, { buffer = true, expr = true, replace_keycodes = true, desc = "Continue markdown list" })
              end,
            })
          '';

          keymaps = ''
            vim.keymap.set("n", "<leader>o", function()
              vim.fn.jobstart({ "open-in-obsidian", vim.fn.expand("%:p") })
            end, { desc = "Open in Obsidian" })

            vim.keymap.set("v", "<leader>p", function()
              -- Yank the visual selection (not the token under the cursor) and
              -- preview that path.
              vim.cmd('noautocmd normal! "vy')
              local sel = vim.trim(vim.fn.getreg("v"))
              vim.fn.jobstart({ "preview-image", sel })
            end, { desc = "Preview image" })

            vim.keymap.set("n", "<leader>t", function()
              vim.fn.jobstart({ "open-in-ghostty", vim.fn.expand("%:p") })
            end, { desc = "Open in Ghostty" })

            vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word before cursor" })
            vim.keymap.set("i", "<C-h>", "<C-w>", { desc = "Delete word before cursor" })
          '';
        };
      };
    };

  };
}
