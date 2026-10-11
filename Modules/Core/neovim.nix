{ inputs, ... }: {

  flake.nixosModules.Tn-neovim = { config, pkgs, pkgs-stable, lib, ... }:
  let
    openVsx   = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.open-vsx;
    vscodeMkt = inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;

    acLibrary = pkgs.callPackage ./_ac-library.nix { };

    pal = import ./_palette.nix;   # Technonomicon's colours (also nvim)
    c   = pal.roles;

    # VSCodium's theme: a blank canvas with no token rules of its own. A
    # built-in theme's specific selectors (Dark Modern's keyword.control,
    # support.function) out-rank the catch-all rules in userSettings, so
    # `for` and `print` kept their colours. With nothing to compete, the
    # rules below are the whole story. UI colours and token rules stay in
    # userSettings, which each switch merges into settings.json.
    tnTheme = pkgs.vscode-utils.buildVscodeExtension rec {
      pname              = "tn-theme";
      version            = "1.0.0";
      vscodeExtPublisher = "technonomicon";
      vscodeExtName      = "tn-theme";
      vscodeExtUniqueId  = "${vscodeExtPublisher}.${vscodeExtName}";
      src = pkgs.runCommand "tn-theme-src" { } ''
        mkdir -p $out/extension/themes
        cp ${pkgs.writeText "package.json" (builtins.toJSON {
          name        = vscodeExtName;
          displayName = "Technonomicon";
          publisher   = vscodeExtPublisher;
          inherit version;
          engines.vscode = "^1.70.0";
          categories  = [ "Themes" ];
          contributes.themes = [ {
            id = "Technonomicon"; label = "Technonomicon";
            uiTheme = "vs-dark"; path = "./themes/technonomicon.json";
          } ];
        })} $out/extension/package.json
        cp ${pkgs.writeText "technonomicon.json" (builtins.toJSON {
          name = "Technonomicon";
          type = "dark";
          semanticHighlighting = false;
          colors = { "editor.background" = c.bg; "editor.foreground" = c.plain; };
          tokenColors = [ ];
        })} $out/extension/themes/technonomicon.json
      '';
      sourceRoot = "tn-theme-src/extension";
    };

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
    ];

    # VSCodium; `eo` opens projects on Akmon over Open Remote - SSH whenever
    # it's reachable (Tn-dev-client).
    home-manager.users.xin.programs.vscodium = {
      enable  = true;
      profiles.default = {
        extensions = editorExtensions ++ [ tnTheme ];   # the theme is UI-side only
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
          # Technonomicon's colours (_palette.nix, shared with nvim and the
          # desktop) on the blank tnTheme: Dark Reader's ground, flat surfaces
          # with thin borders, blue for focus, and the row being chosen solid
          # blue with dark text.
          "workbench.colorTheme"           = "Technonomicon";   # tnTheme above
          # flash labels: red tags with dark text, matches in teal
          "flash-vscode.labelBackgroundColor"         = c.error;
          "flash-vscode.labelColor"                   = c.bg;
          "flash-vscode.labelQuestionBackgroundColor" = c.accent;
          "flash-vscode.matchColor"                   = c.info;

          "workbench.colorCustomizations" = let
            chosen = { bg = c.accent; fg = c.bg; };
            b      = n: "#${pal.base16.${n}}";
            alpha  = col: a: "${col}${a}";   # #RRGGBB + AA
          in {
            # ground, surfaces, borders
            "focusBorder"                           = c.accent;
            "foreground"                            = c.plain;
            "descriptionForeground"                 = c.second;
            "widget.border"                         = c.border;
            "widget.shadow"                         = "#00000066";
            "editor.background"                     = c.bg;
            "editor.foreground"                     = c.plain;
            "editorGutter.background"               = c.bg;
            "sideBar.background"                    = c.bg;
            "sideBar.border"                        = c.border;
            "sideBarSectionHeader.background"       = c.bg;
            "sideBarSectionHeader.border"           = c.border;
            "panel.background"                      = c.bg;
            "panel.border"                          = c.border;
            "activityBar.background"                = c.bg;
            "activityBar.border"                    = c.border;
            "titleBar.activeBackground"             = c.bg;
            "titleBar.inactiveBackground"           = c.bg;
            "titleBar.border"                       = c.border;
            "editorGroupHeader.tabsBackground"      = c.bg;
            "editorGroup.border"                    = c.border;
            "tab.activeBackground"                  = c.bg;
            "tab.inactiveBackground"                = c.bg;
            "tab.border"                            = c.border;
            "statusBar.background"                  = c.surface;
            "statusBar.foreground"                  = c.second;
            "statusBar.border"                      = c.border;
            "statusBar.noFolderBackground"          = c.surface;
            "statusBar.debuggingBackground"         = c.warn;
            "statusBar.debuggingForeground"         = c.bg;
            "editorWidget.background"               = c.surface;
            "editorWidget.border"                   = c.border;
            "editorHoverWidget.background"          = c.surface;
            "editorHoverWidget.border"              = c.border;
            "quickInput.background"                 = c.surface;
            "menu.background"                       = c.surface;
            "menu.border"                           = c.border;
            "notifications.background"              = c.surface;
            "notifications.border"                  = c.border;
            "peekViewEditor.background"             = c.surface;
            "peekViewResult.background"             = c.surface;
            "input.background"                      = c.bg;
            "input.border"                          = c.border;
            "dropdown.background"                   = c.surface;
            "dropdown.border"                       = c.border;
            "button.background"                     = c.accent;
            "button.foreground"                     = c.bg;
            "badge.background"                      = c.accent;
            "badge.foreground"                      = c.bg;
            "scrollbarSlider.background"            = alpha c.dim "33";
            "scrollbarSlider.hoverBackground"       = alpha c.dim "55";
            "scrollbarSlider.activeBackground"      = alpha c.dim "77";
            # the text area
            "editor.lineHighlightBackground"        = c.linehl;
            "editor.lineHighlightBorder"            = c.linehl;
            "editorLineNumber.foreground"           = c.dim;
            "editorLineNumber.activeForeground"     = c.plain;
            "editorCursor.foreground"               = c.plain;
            "editor.selectionBackground"            = c.sel;
            "editor.inactiveSelectionBackground"    = alpha c.sel "99";
            "editor.selectionHighlightBackground"   = alpha c.sel "66";
            "editor.wordHighlightBackground"        = "#00000000";
            "editor.wordHighlightStrongBackground"  = "#00000000";
            "editor.wordHighlightBorder"            = c.border;
            # search hits: an orange outline and a see-through fill, so the
            # token colours still show
            "editor.findMatchBackground"            = alpha c.search "6B";
            "editor.findMatchBorder"                = c.search;
            "editor.findMatchHighlightBackground"   = alpha c.search "38";
            "editor.findMatchHighlightBorder"       = alpha c.search "99";
            "editorBracketMatch.background"         = "#00000000";
            "editorBracketMatch.border"             = c.search;
            "editorWhitespace.foreground"           = c.whitespace;
            "editorIndentGuide.background1"         = c.whitespace;
            "editorIndentGuide.activeBackground1"   = c.dim;
            "editorInlayHint.foreground"            = c.dim;
            "editorInlayHint.background"            = "#00000000";
            "editorInlayHint.typeForeground"        = c.dim;
            "editorInlayHint.typeBackground"        = "#00000000";
            "editorInlayHint.parameterForeground"   = c.dim;
            "editorInlayHint.parameterBackground"   = "#00000000";
            "editorError.foreground"                = c.error;
            "editorWarning.foreground"              = c.warn;
            "editorInfo.foreground"                 = c.info;
            "editorHint.foreground"                 = c.hint;
            "editorGutter.addedBackground"          = c.add;
            "editorGutter.modifiedBackground"       = c.change;
            "editorGutter.deletedBackground"        = c.del;
            "diffEditor.insertedTextBackground"     = alpha c.add "26";
            "diffEditor.removedTextBackground"      = alpha c.del "26";
            "editorLink.activeForeground"           = c.accent;
            "textLink.foreground"                   = c.accent;
            "textLink.activeForeground"             = c.accent;
            # the terminal: Ghostty's colours
            "terminal.background"                   = c.bg;
            "terminal.foreground"                   = c.plain;
            "terminalCursor.foreground"             = c.plain;
            "terminal.selectionBackground"          = c.accent;
            "terminal.selectionForeground"          = c.bg;
            "terminal.ansiBlack"                    = c.bg;
            "terminal.ansiRed"                      = b "base08";
            "terminal.ansiGreen"                    = b "base0B";
            "terminal.ansiYellow"                   = b "base0A";
            "terminal.ansiBlue"                     = b "base0D";
            "terminal.ansiMagenta"                  = b "base0E";
            "terminal.ansiCyan"                     = b "base0C";
            "terminal.ansiWhite"                    = c.plain;
            "terminal.ansiBrightBlack"              = c.dim;
            "terminal.ansiBrightRed"                = b "base08";
            "terminal.ansiBrightGreen"              = b "base0B";
            "terminal.ansiBrightYellow"             = b "base0A";
            "terminal.ansiBrightBlue"               = b "base0D";
            "terminal.ansiBrightMagenta"            = b "base0E";
            "terminal.ansiBrightCyan"               = b "base0C";
            "terminal.ansiBrightWhite"              = c.bright;
            # The row being chosen in every dropdown and list (completion,
            # quick fix, command palette, pickers, menus, settings selects):
            # solid blue with dark text, in every state, since an unset one
            # falls back to the theme's faint default. Matched letters are
            # blue elsewhere and dark on the chosen row.
            "editorActionList.focusBackground"      = chosen.bg;
            "editorActionList.focusForeground"      = chosen.fg;
            "editorSuggestWidget.background"        = c.surface;
            "editorSuggestWidget.border"            = c.border;
            "editorSuggestWidget.foreground"        = c.plain;
            "editorSuggestWidget.highlightForeground" = c.accent;
            "editorSuggestWidget.selectedBackground" = chosen.bg;
            "editorSuggestWidget.selectedForeground" = chosen.fg;
            "editorSuggestWidget.selectedIconForeground" = chosen.fg;
            "editorSuggestWidget.focusHighlightForeground" = chosen.fg;
            "quickInputList.focusBackground"        = chosen.bg;
            "quickInputList.focusForeground"        = chosen.fg;
            "quickInputList.focusIconForeground"    = chosen.fg;
            "list.activeSelectionBackground"        = chosen.bg;
            "list.activeSelectionForeground"        = chosen.fg;
            "list.activeSelectionIconForeground"    = chosen.fg;
            "list.inactiveSelectionBackground"      = c.sel;
            "list.inactiveSelectionForeground"      = c.plain;
            "list.focusBackground"                  = chosen.bg;
            "list.focusForeground"                  = chosen.fg;
            "list.focusHighlightForeground"         = chosen.fg;
            "list.highlightForeground"              = c.accent;
            "list.focusOutline"                     = c.accent;
            "list.focusAndSelectionOutline"         = c.accent;
            "list.inactiveFocusOutline"             = c.border;
            "list.hoverBackground"                  = c.sel;
            "list.hoverForeground"                  = c.plain;
            "menu.selectionBackground"              = chosen.bg;
            "menu.selectionForeground"              = chosen.fg;
          };
          # Tonsky's minimal highlighting, the same as nvim (_tn-nvim.lua):
          # comments yellow, strings green, constants red, *definitions*
          # blue, punctuation and operators grey; keywords, calls and
          # variables plain; no bold or italic. The more specific scope wins,
          # so the catch-alls can come first. Not keyed to a theme name: a
          # renamed theme silently drops theme-keyed rules (it happened), and
          # tnTheme has no rules of its own to out-rank these.
          "editor.tokenColorCustomizations".textMateRules = let
            rule = scope: settings: { inherit scope settings; };
          in [
            (rule [
              "keyword" "storage" "variable" "variable.language"
              "variable.parameter" "support" "entity.name.function"
              "entity.name.type" "entity.name.tag" "entity.name.namespace"
              "entity.other.attribute-name" "entity.other.inherited-class"
              "meta.function-call" "meta.decorator" "constant.other"
              "markup.inline.raw"
              # word operators read as keywords (and, or, not, in, is, typeof)
              "keyword.operator.logical" "keyword.operator.word"
              "keyword.operator.expression" "keyword.operator.new"
              "keyword.operator.wordlike"
            ] { foreground = c.plain; fontStyle = ""; })
            (rule [
              "punctuation" "keyword.operator" "meta.brace"
              "constant.character.escape" "constant.character.format.placeholder"
              "storage.type.format" "punctuation.section.embedded"
            ] { foreground = c.punct; fontStyle = ""; })
            (rule [ "string" "punctuation.definition.string" "string.regexp" ]
              { foreground = c.string; })
            (rule [
              "constant.numeric" "constant.language" "constant.character"
              "constant.other.color" "constant.other.symbol"
              "keyword.other.unit" "support.constant"
            ] { foreground = c.const; })
            (rule [
              "meta.function entity.name.function"
              "meta.function.definition entity.name.function"
              "meta.definition.function entity.name.function"
              "meta.function support.function.magic"
              "entity.name.function.definition" "entity.name.class"
              "entity.name.type.class" "entity.name.type.struct"
              "entity.name.type.enum" "entity.name.type.interface"
              "entity.name.type.alias" "entity.name.type.typedef"
              # nix: the name on the left of `=` is the definition
              "entity.other.attribute-name.single.nix"
              "entity.other.attribute-name.multipart.nix"
              "entity.name.section" "markup.heading"
            ] { foreground = c.def; fontStyle = ""; })
            (rule [
              "comment" "punctuation.definition.comment"
              # the quotes too: this must out-rank the string rule's
              # punctuation.definition.string, so it names the same scope
              "string.quoted.docstring"
              "string.quoted.docstring punctuation.definition.string"
              "comment.block.documentation"
            ] { foreground = c.comment; fontStyle = ""; })
            (rule [ "invalid" "invalid.illegal" ] { foreground = c.error; })
            (rule [ "markup.inserted" ] { foreground = c.add; })
            (rule [ "markup.deleted" ] { foreground = c.del; })
            (rule [ "markup.changed" ] { foreground = c.change; })
          ];
          # Language servers' semantic tokens would repaint variables, types
          # and calls in colour on top of the rules above, and coloured
          # bracket pairs are highlighting the post argues against.
          "editor.semanticHighlighting.enabled" = false;
          "editor.bracketPairColorization.enabled" = false;
          "editor.guides.bracketPairs"     = false;
          "editor.fontFamily"              = "'${config.tn.primary_font}', monospace";
          "editor.fontLigatures"           = true;
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

          # .qmd is the Quarto extension's own language (preview, render,
          # cells). Stated outright: settings.json is merged, never pruned,
          # so the old "markdown" association would otherwise stay in it.
          "files.associations" = { "*.qmd" = "quarto"; };

          # Formatters are all already on PATH via systemPackages above.
          "editor.formatOnSave"      = true;
          "editor.wordWrap"          = "on";
          "editor.renderLineHighlight" = "all";
          # the mono font carries the Nerd Font icons (eza/starship)
          "terminal.integrated.fontFamily" = "'${config.tn.primary_font}', monospace";
          "terminal.integrated.fontLigatures.enabled" = true;
          # the first terminal (F4) opens in the active file's folder; after
          # that F4 shows and hides the same one (`nt` for a separate window)
          "terminal.integrated.cwd" = "\${fileDirname}";
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

      # image.nvim's magick luarock, from nix instead of luarocks
      programs.neovim.extraLuaPackages = ps: [ ps.magick ];
      # molten is a Python remote plugin: it runs in nvim's own provider
      # (pynvim is already there), so its dependencies go there too.
      # jupyter-client is required; the rest render and export outputs.
      programs.neovim.extraPython3Packages = ps: with ps; [
        jupyter-client nbformat cairosvg pillow pyperclip
      ];

      # Definitions are blue, as in VSCodium, but these languages have no
      # definition-only capture for them: Nix binding names (not attribute
      # access) and Python class/def names. _tn-nvim.lua colours @tn.def.
      xdg.configFile."nvim/after/queries/nix/highlights.scm".text = ''
        ;; extends
        (binding attrpath: (attrpath attr: (identifier) @tn.def))
      '';
      xdg.configFile."nvim/after/queries/python/highlights.scm".text = ''
        ;; extends
        (class_definition name: (identifier) @tn.def)
        (function_definition name: (identifier) @tn.def)
      '';

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

          # Technonomicon's colours (_palette.nix, _tn-nvim.lua). mini.base16
          # is nixpkgs' copy, loaded by path, so lazy.nvim clones nothing and
          # the first start works offline.
          colorscheme = ''
            return {
              { dir = "${pkgs.vimPlugins.mini-base16}", name = "mini.base16", lazy = true },
              {
                "LazyVim/LazyVim",
                opts = {
                  colorscheme = function()
                    require("lazy").load({ plugins = { "mini.base16" } })
                    ${pal.lua}
                    ${builtins.readFile ./_tn-nvim.lua}
                  end,
                },
              },
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
