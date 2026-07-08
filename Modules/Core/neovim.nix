{ inputs, ... }: {

  flake.nixosModules.Tn-neovim = { pkgs, ... }:
  let
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
      hyprctl dispatch focuswindow "class:^(obsidian)$" \
        || hyprctl dispatch focuswindow "class:^(Obsidian)$"
    '';
  in {

    environment.systemPackages = with pkgs; [
      previewImage
      openInGhostty
      openInObsidian
      imv
      zellij
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
      # AI Coding
      aider-chat
      # Markdown LSP
      marksman
      markdown-oxide
      # General Tooling
      qalculate-gtk
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
      # LaTeX
      texlive.combined.scheme-full
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
      # Jupyter Notebooks
      zeromq
      python3Packages.jupyter
    ];

    home-manager.users.xin.programs.vscodium = {
      enable = true;
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          arcticicestudio.nord-visual-studio-code
        ];
        userSettings = {
          "workbench.colorTheme"           = "Nord";
          "editor.fontFamily"              = "'JetBrains Mono', monospace";
          "editor.fontSize"                = 14;
          "editor.lineNumbers"             = "relative";
          "editor.minimap.enabled"         = false;
          "workbench.activityBar.location" = "hidden";
        };
      };
    };

    home-manager.users.xin.home.file = {
      ".config/yazi/yazi.toml".text = ''
        [opener]
        edit = [
          { run = 'nvim "$@"', block = true, desc = "Neovim" },
        ]
      '';

      ".config/yazi/keymap.toml".text = ''
        [[manager.prepend_keymap]]
        on   = [ "d" ]
        run  = "shell 'trash-put \"$@\"' --confirm"
        desc = "Move to trash"

        [[manager.prepend_keymap]]
        on   = [ "D" ]
        run  = "remove --permanently"
        desc = "Permanently delete"
      '';

      ".config/ghostty/config".text = ''
        confirm-close-surface = false
        command = zellij
      '';

      ".config/zellij/config.kdl".text = ''
        pane_frames false
        simplified_ui true
        default_layout "bare"
        show_startup_tips false
        show_release_notes false
        copy_on_select true
        scrollback_editor "nvim"

        keybinds {
          normal {
            bind "Ctrl e" { EditScrollback; SwitchToMode "Normal"; }
          }
          scroll {
            bind "Up"       { ScrollUp; }
            bind "Down"     { ScrollDown; }
            bind "PageUp"   { PageScrollUp; }
            bind "PageDown" { PageScrollDown; }
            bind "Home"     { ScrollToTop; }
            bind "End"      { ScrollToBottom; }
          }
        }
      '';

      ".config/zellij/layouts/bare.kdl".text = ''
        layout {
          pane
        }
      '';
    };

    home-manager.users.xin = {
      imports = [ inputs.lazyvim.homeManagerModules.default ];

      programs.lazyvim = {
        enable = true;

        extras = {
          lang.nix              = { enable = true; };
          lang.python           = { enable = true; installDependencies = false; };
          lang.typescript       = { enable = true; installDependencies = false; };
          lang.tex              = { enable = true; };
          editor."undo-tree"    = { enable = true; };
        };

        plugins = {

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
                  hls      = {},
                  clangd   = {},
                  zls      = {},
                  marksman = {},
                },
              },
            }
          '';
        };

        config = {
          options = ''
            vim.opt.relativenumber = true
            vim.opt.cursorline     = true
            vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"
          '';

          autocmds = ''
            vim.api.nvim_create_autocmd("BufWritePre", {
              pattern = "*",
              callback = function()
                local pos = vim.api.nvim_win_get_cursor(0)
                vim.cmd([[%s/\s\+$//e]])
                vim.api.nvim_win_set_cursor(0, pos)
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
            vim.keymap.set("i", "<Esc>", "<Esc>:w<CR>", { desc = "Normal + save" })
            vim.keymap.set("i", "<C-c>", "<Esc>:w<CR>", { desc = "Normal + save" })

            vim.keymap.set("n", "<leader>o", function()
              vim.fn.jobstart({ "open-in-obsidian", vim.fn.expand("%:p") })
            end, { desc = "Open in Obsidian" })

            vim.keymap.set("v", "<leader>p", function()
              local sel = vim.fn.expand("<cfile>")
              vim.fn.jobstart({ "preview-image", sel })
            end, { desc = "Preview image" })

            vim.keymap.set("n", "<leader>t", function()
              vim.fn.jobstart({ "open-in-ghostty", vim.fn.expand("%:p") })
            end, { desc = "Open in Ghostty" })
          '';
        };
      };
    };

  };
}
