{ inputs, ... }: {

  flake.nixosModules.Tn-helix = { pkgs, ... }:
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
      helix
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

    home-manager.users.xin.programs.vscode = {
      enable = true;
      package = pkgs.vscodium;
      extensions = with pkgs.vscode-extensions; [
        arcticicestudio.nord-visual-studio-code
      ];
      userSettings = {
        "workbench.colorTheme"        = "Nord";
        "editor.fontFamily"           = "'JetBrains Mono', monospace";
        "editor.fontSize"             = 14;
        "editor.lineNumbers"          = "relative";
        "editor.minimap.enabled"      = false;
        "workbench.activityBar.location" = "hidden";
      };
    };

    home-manager.users.xin.home.file = {
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
      '';

      ".config/zellij/layouts/bare.kdl".text = ''
        layout {
          pane
        }
      '';

      ".config/helix/config.toml".text = ''
        theme = "nord"

        [editor]
        line-number        = "relative"
        cursorline         = true
        color-modes        = true
        idle-timeout       = 200
        completion-replace = true

        [editor.cursor-shape]
        insert = "bar"
        normal = "block"
        select = "underline"

        [editor.indent-guides]
        render = true

        [editor.statusline]
        left  = ["mode", "spinner", "file-name", "file-modification-indicator"]
        right = ["diagnostics", "position", "file-encoding", "file-type"]

        [keys.normal.space]
        f     = ":format"
        space = "file_picker"
        o     = ":sh open-in-obsidian %val{filename}"
        p     = ":sh preview-image %val{selection}"
      '';

      ".config/helix/languages.toml".text = ''
        [[language]]
        name = "nix"
        language-servers = ["nixd"]
        formatter = { command = "nixfmt" }
        auto-format = true

        [[language]]
        name = "python"
        language-servers = ["pyright"]
        formatter = { command = "black", args = ["-", "--quiet"] }
        auto-format = true

        [[language]]
        name = "haskell"
        language-servers = ["haskell-language-server"]

        [[language]]
        name = "typescript"
        language-servers = ["typescript-language-server"]
        formatter = { command = "prettier", args = ["--parser", "typescript"] }
        auto-format = true

        [[language]]
        name = "tsx"
        language-servers = ["typescript-language-server"]
        formatter = { command = "prettier", args = ["--parser", "typescript"] }
        auto-format = true

        [[language]]
        name = "javascript"
        language-servers = ["typescript-language-server"]
        formatter = { command = "prettier", args = ["--parser", "babel"] }
        auto-format = true

        [[language]]
        name = "jsx"
        language-servers = ["typescript-language-server"]
        formatter = { command = "prettier", args = ["--parser", "babel"] }
        auto-format = true

        [[language]]
        name = "c"
        language-servers = ["clangd"]

        [[language]]
        name = "cpp"
        language-servers = ["clangd"]

        [[language]]
        name = "zig"
        language-servers = ["zls"]
        auto-format = true

        [language-server.markdown-oxide]
        command = "markdown-oxide"

        [[language]]
        name = "markdown"
        language-servers = ["markdown-oxide", "marksman"]
        formatter = { command = "prettier", args = ["--parser", "markdown"] }

        [[language]]
        name = "json"
        formatter = { command = "prettier", args = ["--parser", "json"] }
        auto-format = true

        [[language]]
        name = "html"
        formatter = { command = "prettier", args = ["--parser", "html"] }
        auto-format = true

        [[language]]
        name = "css"
        formatter = { command = "prettier", args = ["--parser", "css"] }
        auto-format = true
      '';
    };
  };
}
