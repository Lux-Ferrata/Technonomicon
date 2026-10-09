{ inputs, ... }: {

  flake.nixosModules.Tn-neovim = { config, pkgs, pkgs-stable, lib, ... }:
  let
    openVsx   = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.open-vsx;
    vscodeMkt = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;

    acLibrary = pkgs.callPackage ./_ac-library.nix { };

    # Installed locally by home-manager, and on Akmon's VSCodium server through
    # remote.SSH.defaultExtensions (by ID, from Open VSX).
    editorExtensions = (with openVsx; [
      # Not packaged in nixpkgs. Deliberately left without a `quarto.path`
      # so the blog flake's direnv-provided CLI is the one it picks up.
      quarto.quarto
      # Remote windows on Akmon (Tn-dev-client's `eo`). MS's Remote-SSH is
      # licensed to official VS Code only; this is the open replacement,
      # and VSCodium's product.json already allows its proposed APIs.
      jeanp413.open-remote-ssh
      # Code completion (and later chat/edit) from local llama.cpp models
      ggml-org.llama-vscode
      # Grammar/style in LaTeX, Markdown and Typst, against Akmon's
      # LanguageTool (MPL-2.0)
      ltex-plus.vscode-ltex-plus
      # flash.nvim-style jump labels (MIT), on `s` below
      souravahmed.flash-vscode-latest
    ]) ++ [
      # Harpoon-style pinned files (MIT). Published only to the MS
      # marketplace, so it comes from that index rather than Open VSX --
      # and so Akmon's server can't fetch it: it runs on the UI side
      # (uiExtensions), which works on remote files too.
      vscodeMkt.tobias-z.vscode-harpoon
    ] ++ (with pkgs.vscode-extensions; [
      arcticicestudio.nord-visual-studio-code
      vscodevim.vim
      # Every extension below is MIT/BSD0 and Open-VSX-clean. Pylance is
      # deliberately absent: it is unfree and refuses to run on VSCodium.
      # basedpyright is the pyright fork that rebuilds its extras (inlay
      # hints, builtin docstrings, better auto-imports).
      mkhl.direnv
      jnoortheen.nix-ide
      detachhead.basedpyright
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

    # Extensions that run on the local (UI) side even in remote windows:
    # the remote connector itself, and Harpoon (marketplace-only, so Akmon's
    # server can't fetch it).
    uiExtensions = [
      "jeanp413.open-remote-ssh"
      "tobias-z.vscode-harpoon"
    ];

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

    # Compilers, language servers, formatters and the rest of the headless
    # toolchain live in Tn-devtools (shared with Akmon, where remote editor
    # windows run). This is the desktop/editor side only.
    environment.systemPackages = with pkgs; [
      previewImage
      openInGhostty
      openInObsidian
      imv
      ghostty
      # File Management
      yazi
      # Accounting
      beancount
      # General Tooling
      qalculate-gtk
      libqalculate # provides the `qalc` CLI
      # Chart Tooling
      mermaid-cli
      drawio
      pdf2svg
      # PDF Tooling
      poppler
      # nvim's notebook/image plugins (molten, image.nvim)
      python3Packages.pynvim
      python3Packages.cairosvg
      mcpy
      # image.nvim — provides the magick luarock via nix instead of luarocks
      luajitPackages.magick
    ];

    # VSCodium; `eo` opens projects on Akmon over Open Remote - SSH whenever
    # it's reachable (Tn-dev-client).
    home-manager.users.xin.programs.vscodium = {
      enable  = true;
      profiles.default = {
        extensions = editorExtensions;
        # settings.json is a real file: each switch merges userSettings into
        # it (these win), and keys VSCodium writes itself -- e.g. the
        # llama-vscode menu's completion toggle -- survive.
        mutableUserSettings = true;

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
          # While a flash jump is active, Escape and Backspace belong to it,
          # not to VSCodeVim (user keybindings win over both extensions').
          { key = "escape";    command = "flash-vscode.exit";      when = "flash-vscode.active"; }
          { key = "backspace"; command = "flash-vscode.backspace"; when = "flash-vscode.active && editorTextFocus"; }
        ]
        # Alt+1..5 jumps to harpoon slot N from any mode, terminal included
        ++ map (n: {
          key     = "alt+${toString n}";
          command = "vscode-harpoon.gotoEditor${toString n}";
        }) [ 1 2 3 4 5 ];

        userSettings = {
          "workbench.colorTheme"           = "Nord";
          # flash labels in Nord: red tags with dark text, matches in frost
          "flash-vscode.labelBackgroundColor"         = "#BF616A";
          "flash-vscode.labelColor"                   = "#2E3440";
          "flash-vscode.labelQuestionBackgroundColor" = "#5E81AC";
          "flash-vscode.matchColor"                   = "#88C0D0";

          # Nord's selected row in dropdowns (quick fix, completion, command
          # palette, context menus) is a barely-lighter grey. Make it solid
          # frost (nord8) with dark text (nord0) so the active item is obvious.
          #
          # High-contrast Nord: the editor sits on a deeper night (#1E222A)
          # than nord0, so plain text (nord6) is ~14:1 and every syntax
          # colour below clears 8:1 (WCAG AAA). Line numbers are lifted from
          # nord3, which nearly vanishes on the darker ground.
          "workbench.colorCustomizations" = let
            sel = { bg = "#88C0D0"; fg = "#2E3440"; };
            bg  = "#1E222A";
          in {
            "editor.background"                     = bg;
            "editor.foreground"                     = "#ECEFF4";  # nord6
            "editorGutter.background"               = bg;
            "editorLineNumber.foreground"           = "#7B88A1";
            "editorLineNumber.activeForeground"     = "#ECEFF4";
            "panel.background"                      = bg;
            "terminal.background"                   = bg;
            "terminal.foreground"                   = "#ECEFF4";
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
          # Tonsky/Alabaster-style syntax on Nord: highlight what reading
          # needs, not grammar. Comments are bright gold (~10:1) because
          # they matter; strings, constants and *definitions* get a saturated
          # Nord hue; keywords, calls, variables and punctuation are plain
          # (nord6) text. All >= 8:1 on the editor background above. Later
          # rules win, so the catch-all comes first and comments last.
          "editor.tokenColorCustomizations"."[Nord]".textMateRules = let
            rule = scope: settings: { inherit scope settings; };
            plain = "#ECEFF4";  # nord6
          in [
            (rule [
              "keyword" "storage" "keyword.operator" "punctuation"
              "variable" "variable.language" "variable.parameter" "support"
              "entity.name.function" "entity.name.type" "entity.name.tag"
              "entity.name.namespace" "entity.other.attribute-name"
              "entity.other.inherited-class" "meta.function-call"
              "meta.decorator" "constant.other" "markup.inline.raw"
            ] { foreground = plain; fontStyle = ""; })
            (rule [ "string" "punctuation.definition.string" ]
              { foreground = "#B5E689"; })  # nord14, saturated
            (rule [
              "constant.numeric" "constant.language" "constant.character"
              "constant.other.color" "keyword.other.unit" "support.constant"
            ] { foreground = "#EBA2DE"; })  # nord15, saturated
            (rule [
              "meta.function entity.name.function"
              "meta.function.definition entity.name.function"
              "meta.definition.function entity.name.function"
              "entity.name.function.definition" "entity.name.class"
              "entity.name.type.class" "entity.name.type.struct"
              "entity.name.type.enum" "entity.name.type.interface"
              "entity.name.type.alias" "entity.name.type.typedef"
              "entity.name.function.macro"
              # nix: the name on the left of `=` is the definition
              "entity.other.attribute-name.single.nix"
              "entity.other.attribute-name.multipart.nix"
              "entity.name.section"
            ] { foreground = "#7BDAF4"; })  # nord8, saturated
            (rule [
              "comment" "punctuation.definition.comment"
              "string.quoted.docstring" "string.quoted.docstring punctuation"
              "comment.block.documentation"
            ] { foreground = "#FBC260"; fontStyle = ""; })  # gold, nord13's hue deepened
          ];
          # Language servers' semantic tokens would repaint variables, types
          # and calls in colour on top of the rules above.
          "editor.semanticHighlighting.enabled" = false;
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

          # LTeX+: the nixpkgs server (on PATH on both hosts, Tn-devtools)
          # rather than a download, checking against Akmon's LanguageTool
          # (English n-grams + zh-CN; tailnet only, so no grammar offline).
          # `auto` lets the server tell English from Mandarin; a file can pin
          # it with a `% LTeX: language=zh-CN` comment.
          "ltex.ltex-ls.path"                = "${pkgs.ltex-ls-plus}";
          "ltex.languageToolHttpServerUri"   = "https://lt.ironshark.org/";
          "ltex.language"                    = "auto";

          # Quarto has no packaged extension; .qmd is markdown plus fenced
          # cells, so this gets highlighting without one.
          "files.associations" = { "*.qmd" = "markdown"; };

          # Formatters are all already on PATH via systemPackages above.
          "editor.formatOnSave"      = true;
          "editor.wordWrap"          = "on";
          "editor.renderLineHighlight" = "all";
          # Nerd Font variant: eza/starship icons render instead of boxes
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font', monospace";
          # let F4 and the harpoon jumps through instead of sending them to fish
          "terminal.integrated.commandsToSkipShell" = [
            "workbench.action.terminal.toggleTerminal"
          ] ++ map (n: "vscode-harpoon.gotoEditor${toString n}") [ 1 2 3 4 5 ];
          "telemetry.telemetryLevel" = "off";
          # nix owns versions, locally and (by ID) on Akmon's server
          "update.mode"            = "none";
          "extensions.autoUpdate"  = false;
          "extensions.autoCheckUpdates" = false;

          # Open Remote - SSH. Akmon's login shell is fish, so tell it the
          # platform rather than letting it probe; ControlMaster etc. come
          # from ~/.ssh/config (Tn-dev-client).
          "remote.SSH.remotePlatform"    = { akmon = "linux"; };
          # everything except what runs on this (UI) side
          "remote.SSH.defaultExtensions" = lib.subtractLists uiExtensions
            (map (e: e.vscodeExtUniqueId) editorExtensions);
          "remote.extensionKind" = lib.genAttrs uiExtensions (_: [ "ui" ]);

          # llama-vscode runs next to the code (it needs the Git extension,
          # which does too), and 127.0.0.1:8012 is right on either side: on
          # Akmon it's the GPU server itself, on Kvasir the proxy that
          # prefers Akmon and falls back to the CPU model (Tn-dev-client).
          "llama-vscode.endpoint"             = "http://127.0.0.1:8012";
          # chat, edit-selection and the tool-using agent: same idea, :8011
          # (Akmon wakes its chat model on the first request)
          "llama-vscode.endpoint_chat"        = "http://127.0.0.1:8011";
          "llama-vscode.endpoint_tools"       = "http://127.0.0.1:8011";
          "llama-vscode.ask_install_llamacpp" = false;
          "llama-vscode.rag_enabled"          = false;

          # ms-python.python would otherwise try to start Pylance; the
          # basedpyright extension provides the language server.
          "python.languageServer" = "None";
          # basedpyright's default "recommended" mode is far stricter than
          # pyright; "standard" keeps the same diagnostics as before.
          "basedpyright.analysis.typeCheckingMode" = "standard";

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
          # `s` is flash, as in LazyVim: type as many characters as you like,
          # labels follow every keystroke, press one to jump (Enter takes
          # the nearest match). Visual `s` extends the selection instead.
          "vim.normalModeKeyBindingsNonRecursive" = [
            { before = [ "s" ]; commands = [ "flash-vscode.start" ]; }
            { before = [ "<Esc>" ]; after = [ "<Esc>" ]; commands = [ "workbench.action.files.saveFiles" ]; }
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
          # Save on leaving insert mode and on <Esc> in normal mode, like the
          # nvim config. saveFiles writes every dirty file but skips untitled
          # ones, so it never pops a save dialog.
          "vim.insertModeKeyBindingsNonRecursive" = [
            { before = [ "<Esc>" ]; after = [ "<Esc>" ]; commands = [ "workbench.action.files.saveFiles" ]; }
          ];
          "vim.visualModeKeyBindingsNonRecursive" = [
            { before = [ "s" ]; commands = [ "flash-vscode.startSelection" ]; }
          ];
        };
      };
    };

    # `eo` is a plain $PATH binary, so putting it here makes VSCodium the
    # default target while still letting a project dev shell win by
    # prepending its own. `--new-window` keeps it from handing the path to
    # an already-open window. When `akmon-ready` (Tn-dev-client) says the
    # project can run on Akmon, the window opens there over Remote-SSH --
    # same path on both machines -- otherwise it opens locally. `eol` is the
    # same thing forced local, even when Akmon is up.
    home-manager.users.xin.home.packages = let
      eo = pkgs.writeShellScriptBin "eo" ''
        code=${pkgs.vscodium}/bin/codium
        # the CLI half of `codium` warns about the wrapper's Wayland flags,
        # which are meant for the window; drop just those lines
        exec 2> >(grep -v "is not in the list of known options" >&2)
        [ "$#" -eq 0 ] && set -- .
        if [ -z "''${EO_LOCAL:-}" ] && command -v akmon-ready >/dev/null && akmon-ready "$1"; then
          args=()
          for p in "$@"; do
            p=$(realpath -m -- "$p")
            if [ -d "$p" ]; then args+=(--folder-uri "vscode-remote://ssh-remote+akmon$p")
            else                 args+=(--file-uri   "vscode-remote://ssh-remote+akmon$p"); fi
          done
          exec "$code" --new-window "''${args[@]}"
        fi
        exec "$code" --new-window "$@"
      '';
    in [
      eo
      (pkgs.writeShellScriptBin "eol" ''
        EO_LOCAL=1 exec ${eo}/bin/eo "$@"
      '')
    ];

    home-manager.users.xin.home.file = {
      # Personal code snippets: snippets/<language>.json in this repo, VS Code
      # format, added as needed. A live symlink (not a store copy), so
      # "Snippets: Configure Snippets" in VSCodium edits -- and creates new
      # language files in -- the repo itself. LazyVim loads the same files
      # (LuaSnip spec below) and tn-snip (Super+Shift+H) searches them. Plain
      # JSON only: LuaSnip's .json parser rejects comments.
      ".config/VSCodium/User/snippets".source =
        config.home-manager.users.xin.lib.file.mkOutOfStoreSymlink
          "/home/xin/Projects/Technonomicon/snippets";

      ".config/yazi/yazi.toml".text = ''
        [mgr]
        show_hidden    = false
        sort_by        = "natural"
        sort_dir_first = true
        linemode       = "mtime"
        scrolloff      = 5

        # Enter on text/code opens VSCodium via `eo` (detached); `O` offers nvim too
        [opener]
        edit = [
          { run = 'eo "$@"', orphan = true, desc = "VSCodium" },
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
        run  = "shell 'eo .' --orphan"
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
                ${builtins.readFile ./_nord-alabaster.lua}
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

          # The repo's snippets/<language>.json (shared with VSCodium and
          # tn-snip). LuaSnip only maps files to languages through a
          # package.json, so one is generated at startup in the cache dir,
          # next to symlinks to the files: a new language file needs no edit
          # here. Same setup(opts) the default config would run.
          snippets = ''
            return {
              "L3MON4D3/LuaSnip",
              config = function(_, opts)
                require("luasnip").setup(opts)
                local src   = vim.fn.expand("~/Projects/Technonomicon/snippets")
                local cache = vim.fn.stdpath("cache") .. "/tn-snippets"
                vim.fn.delete(cache, "rf")
                vim.fn.mkdir(cache, "p")
                local entries = {}
                for _, file in ipairs(vim.fn.glob(src .. "/*.json", false, true)) do
                  local name = vim.fn.fnamemodify(file, ":t")
                  vim.uv.fs_symlink(file, cache .. "/" .. name)
                  table.insert(entries, { language = vim.fn.fnamemodify(name, ":r"), path = "./" .. name })
                end
                vim.fn.writefile({ vim.json.encode({ name = "tn-snippets", contributes = { snippets = entries } }) },
                  cache .. "/package.json")
                require("luasnip.loaders.from_vscode").lazy_load({ paths = { cache } })
              end,
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

            -- Write the current buffer if it has unsaved changes. Guarded so it
            -- never errors on scratch/terminal/nameless/readonly buffers (E32).
            -- Shared by the InsertLeave autosave and the normal-mode <Esc> map.
            function _G.tn_autosave()
              local buf = vim.api.nvim_get_current_buf()
              if vim.bo[buf].buftype ~= "" then return end
              if vim.api.nvim_buf_get_name(buf) == "" then return end
              if not vim.bo[buf].modifiable or vim.bo[buf].readonly then return end
              if vim.bo[buf].modified then vim.cmd("silent! write") end
            end
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

            -- Autosave on every switch to normal mode.
            vim.api.nvim_create_autocmd("InsertLeave", {
              pattern = "*",
              callback = function() tn_autosave() end,
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

            -- <Esc> in normal mode also saves. Overrides LazyVim's normal-mode
            -- <Esc>, so its :noh is kept here; insert-mode <Esc> is untouched
            -- (InsertLeave already saves).
            vim.keymap.set("n", "<Esc>", function()
              vim.cmd("noh")
              tn_autosave()
            end, { desc = "Clear hlsearch and save" })
          '';
        };
      };
    };

  };
}
