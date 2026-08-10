{ inputs, ... }: {

  flake.nixosModules.Tn-neovim = { pkgs, ... }:
  let
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
      hyprctl eval "hl.dispatch(hl.dsp.focus({window='class:^([oO]bsidian)$'}))"
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
      # General Tooling
      qalculate-gtk
      libqalculate # provides the `qalc` CLI used by qalc.nvim
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
                  hls      = {},
                  clangd   = {},
                  zls      = {},
                  marksman = {},
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

          qalc = ''
            return {
              "Apeiros-46B/qalc.nvim",
              cmd  = { "Qalc", "QalcAttach", "QalcYank" },
              keys = {
                { "<leader>q", "<cmd>Qalc<cr>", desc = "Qalc calculator" },
              },
              config = function()
                require("qalc").setup({})
              end,
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
