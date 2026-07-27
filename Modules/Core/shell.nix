{ inputs, ... }: {
  flake.nixosModules.Tn-shell = { pkgs, config, ... }: {

    programs.xonsh = {
      enable = true;
      extraPackages = ps: [
        (ps.buildPythonPackage {
          pname = "xontrib-fzf-widgets";
          version = "0-unstable-2020-10-16";
          src = pkgs.fetchFromGitHub {
            owner = "laloch";
            repo = "xontrib-fzf-widgets";
            rev = "8af47d1d684a14eb776485ef6f5c30c8e6807f60";
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
      antigravity-ide-fhs
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
