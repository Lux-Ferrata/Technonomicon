{ inputs, ... }: {
  flake.nixosModules.Tn-shell = { pkgs, config, ... }: {

    programs.xonsh = {
      enable = true;
      extraPackages = ps: [
        (ps.buildPythonPackage {
          pname = "xontrib-fzf-widgets";
          version = "master";
          src = pkgs.fetchFromGitHub {
            owner = "laloch";
            repo = "xontrib-fzf-widgets";
            rev = "master";
            hash = "sha256-lz0oiQSLCIQbnoQUi+NJwX82SbUvXJ+3dEsSbOb20q4=";
          };
          pyproject = true;
          build-system = [ ps.setuptools ];
          doCheck = false;
        })

        (ps.buildPythonPackage rec {
          pname = "xonsh-direnv";
          version = "1.6.5";
          src = pkgs.fetchFromGitHub {
            owner = "74th";
            repo = "xonsh-direnv";
            rev = "${version}";
            hash = "sha256-huBJ7WknVCk+WgZaXHlL+Y1sqsn6TYqMP29/fsUPSyU=";
          };
          pyproject = true;
          build-system = [ ps.setuptools ];
          doCheck = false;
        })
      ];
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    home-manager.users.xin = {
      home.file.".config/xonsh/rc.xsh".source = ./_config.xsh;

      programs.git = {
        enable = true;
        settings = {
          user.name  = config.tn.full_name;
          user.email = config.tn.email_address;
          alias = {
            save = "! msg=$(gum write --placeholder 'Commit message...') && [ -n \"$msg\" ] && git add . && git commit -m \"$msg\"";
            send = "! git status && echo -n 'Commit Message: ' && read -r CommitMessage && git add . && git commit -m \"$CommitMessage\" && git push";
            unstage = "restore --staged";
            history = "log --graph --pretty=oneline";
            last = "log -1 HEAD";
          };
          init.defaultBranch = "main";
          pull.rebase = false;
          push.default = "current";
        };
        ignores = [ "*~" ".*~" "#*#" "\\#*\\#" ".*.swp" ];
      };

      programs.gh = {
        enable = true;
        gitCredentialHelper.enable = true;
      };

      programs.broot = {
        enable = true;
        settings.verbs = [
          {
            key = "enter";
            execution = "nvim {file}";
            leave_broot = true;
            apply_to = "file";
          }
        ];
      };

      xdg.configFile."qalculate/qalculate-gtk.cfg".text = ''
        [General]
        version=5.11.0
        allow_multiple_instances=0
        always_on_top=0
        enable_tooltips=1
        error_info_shown=1
        save_mode_on_exit=0
        save_definitions_on_exit=0
        save_history_separately=0
        auto_update_exchange_rates=-1
        clear_history_on_exit=0
        history_expression_type=2
        use_custom_history_font=0
        use_custom_expression_font=0
        replace_expression=0
        enable_completion=1
        enable_completion2=1
        completion_min=1
        completion_min2=1
        completion_delay=0
        use_custom_status_font=0
        vertical_button_padding=-1
        horizontal_button_padding=-1
        use_custom_keypad_font=0
        latest_button_currency=USD
        use_custom_result_font=0
        continuous_conversion=1
        set_missing_prefixes=0
        show_bases_keypad=1
        keep_function_dialog_open=0
        ignore_locale=0
        load_global_definitions=1
        local_currency_conversion=1
        use_binary_prefixes=0
        check_version=0
        show_keypad=1
        show_history=0
        show_stack=1
        show_convert=0
        persistent_keypad=0
        minimal_mode=0
        rpn_keys=1
        display_expression_status=1
        parsed_expression_in_resultview=0
        calculate_as_you_type_history_delay=2000
        use_unicode_signs=1
        lower_case_numbers=0
        exp_display=3
        spell_out_logical_operators=1
        digit_grouping=1
        decimal_comma=-1
        multiplication_sign=2
        division_sign=1

        [Mode]
        min_deci=0
        use_min_deci=0
        max_deci=2
        use_max_deci=0
        precision=10
        interval_arithmetic=1
        number_fraction_format=0
        complex_number_form=0
        use_prefixes=1
        abbreviate_names=1
        place_units_separately=1
        auto_post_conversion=3
        mixed_units_conversion=3
        number_base=10
        number_base_expression=10
        read_precision=0
        angle_unit=1
        functions_enabled=1
        variables_enabled=1
        calculate_functions=1
        calculate_variables=1
        units_enabled=1
        allow_complex=1
        allow_infinite=1
        approximation=1
        calculate_as_you_type=0
        in_rpn_mode=1
        chain_mode=0
        parsing_mode=0
        default_assumption_type=4
        default_assumption_sign=0
      '';
    };

    programs.starship = {
      enable = true;
      settings = {
        format = "$directory$nix_shell$git_branch$git_commit$git_state$git_status\n$character";
        time.disabled = true;
        cmd_duration.disabled = true;

        character = {
          success_symbol = "[❯](#539bf5)";
          error_symbol = "[✗](#ff4b00)";
        };

        directory = {
          style = "#539bf5";
          truncate_to_repo = true;
          fish_style_pwd_dir_length = 3;
          format = "[$read_only$path]($style) ";
          read_only = " ";
        };

        git_branch = {
          style = "#539bf5";
          format = "[$symbol$branch]($style) ";
        };

        git_commit = {
          style = "#539bf5";
          format = "[\\($hash$tag\\)]($style) ";
        };

        git_state = {
          style = "#539bf5";
          format = "[\\($state( $progress_current/$progress_total)\\)]($style) ";
        };

        git_status = {
          style = "#539bf5";
          format = "[$conflicted$staged$modified$renamed$deleted$untracked$stashed$ahead_behind]($style) ";

          conflicted = "[ ](bold fg:#539bf5)";
          staged = "[ ](fg:#539bf5)";
          modified = "[ ](fg:#539bf5)";
          renamed = "[ ](fg:#539bf5)";
          deleted = "[ ](fg:#539bf5)";
          untracked = "[? ](fg:#539bf5)";
          stashed = "[ ](fg:#539bf5)";
          ahead = "[ ](fg:#539bf5)";
          behind = "[ ](fg:#539bf5)";
        };
      };
    };

    environment.etc."scripts/clean-power-off.sh" = {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        ${pkgs.libnotify}/bin/notify-send "Shutting down..." "Cleaning up and powering off" &
        timeout 10 find /home/xin/Downloads -mindepth 1 -delete 2>/dev/null || true
        timeout 60 ${pkgs.trash-cli}/bin/trash-empty 10 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl poweroff
      '';
    };

    environment.etc."scripts/clean-reboot.sh" = {
      mode = "0755";
      text = ''
        #!${pkgs.bash}/bin/bash
        timeout 10 find /home/xin/Downloads -mindepth 1 -delete 2>/dev/null || true
        timeout 60 ${pkgs.trash-cli}/bin/trash-empty 10 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl reboot
      '';
    };

    environment.systemPackages = with pkgs; [
      nix-your-shell
      gitFull
      git-lfs
      jujutsu
      lazyjj
      lazydocker
      docker-compose
      btop
      nmon
      kmon
      rsync
      rclone
      wget
      glib
      unzip
      nix-ld
      curl
      zoxide
      gparted
      pciutils
      fastfetch
      udiskie
      trash-cli
      ripgrep
      ripgrep-all
      fd
      fzf
      eza
      entr
      progress
      zip
      caligula
      gum
      sc-im
      glab
      jq
      yq
      dysk
      pastel
      gnumake
      antigravity-fhs
      usbutils
      bat
      mpv
      sox
      aria2
      bzip3
      nemo-with-extensions
      powertop
      # bitwarden-cli
      # bitwarden-desktop
      nvtopPackages.full
      sops
      presenterm
      frogmouth
    ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
      github-desktop
    ];
  };
}
