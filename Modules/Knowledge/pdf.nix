{ inputs, ... }: {
  flake.nixosModules.Tn-pdf = { pkgs, config, ... }: {

    environment.systemPackages = with pkgs; [
      (symlinkJoin {
        name = "sioyek-wrapped";
        paths = [ sioyek ];
        buildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/sioyek \
          --set QT_QPA_PLATFORM xcb
        '';
      })
    ];

    home-manager.users.xin.home.file.".config/sioyek/prefs_user.config".text = ''
      # --- UI & VISUALS ---
  # Start in dark mode automatically
  default_dark_mode 1

  # Soften the dark mode background so it isn't pitch black
  dark_mode_background_color 0.1 0.1 0.1

  # Dim white text in dark mode to prevent eye strain
  dark_mode_contrast 0.8

  # Highlight the current line to keep your place (0 = underline, 1 = box)
  ruler_mode 1

  # --- BEHAVIOR & PERFORMANCE ---
  # Build an index of the PDF for instant regex searches (requires slightly more RAM)
  super_fast_search 1

  # Open clicked links/documents in a new window instead of replacing the current one
  should_launch_new_window 1

  # Smooth out the Vim-style scrolling
  vertical_move_amount 1.0

  # --- INTEGRATION & WORKFLOW ---

  # 1. External Search Engines (Google Scholar, arXiv, Library Genesis)
  search_url_g https://google.com/search?query=
  search_url_s https://scholar.google.com/scholar?q=
  search_url_a https://arxiv.org/search/?query=
  search_url_l http://libgen.rs/search.php?req=

  # 3. Inverse Search (Click PDF -> Jump to Helix)
  inverse_search_command hx "%1:%2"
    '';

    home-manager.users.xin.home.file.".config/sioyek/keys_user.config".text = ''
      # --- CUSTOM NAVIGATION ---
  # Rebind up and down from j/k to u/e
  move_up u
  move_down e

  # --- EMACS-STYLE TEXT SELECTION ---
  # Trigger visual selection hinting using 'v' (mimicking Vim visual mode)
  keyboard_select v

  # --- UTILITY ---
  # Force F8 to toggle dark mode (just in case your OS tries to override it)
  toggle_dark_mode <f8>

  # --- SEARCH ---
  # Overwrite standard search with regex search
  regex_search /
  external_search s
    '';
  };
}
