{ inputs, ... }: {
  flake.nixosModules.Tn-shell = { pkgs, config, ... }: {

    # shared git commit-signing key (ssh format), same identity on every machine
    sops.secrets."git-signing-key" = {
      owner = "xin";
      mode  = "0400";
    };

    # fish is the interactive/login shell; xonsh stays installed for scripting
    programs.fish.enable = true;

    programs.xonsh = {
      enable = true;
      extraPackages = ps: [
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

          # sign every commit/tag with the shared ssh key from sops
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "/home/xin/.config/git/allowed_signers";
          user.signingKey = config.sops.secrets."git-signing-key".path;
          commit.gpgsign = true;
          tag.gpgsign = true;
        };
        ignores = [ "*~" ".*~" "#*#" "\\#*\\#" ".*.swp" ];
      };

      # public half, for local `git log --show-signature` verification
      home.file.".config/git/allowed_signers".text =
        "${config.tn.email_address} ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0ybqlZj+yHx72EgRn+IuxsIi06cC4yQ1+wNbfyq4EV\n";

      programs.gh = {
        enable = true;
        gitCredentialHelper.enable = true;
      };

      programs.fish = {
        enable = true;

        interactiveShellInit = ''
          # keep `nix shell` / `nix develop` in fish instead of dropping to bash
          nix-your-shell fish | source

          # fzf.fish: Ctrl-T files, Ctrl-Alt-L git log, Ctrl-Alt-S git status.
          # History belongs to atuin; Ctrl-V stays paste.
          fzf_configure_bindings --directory=\ct --history= --variables=
        '';

        shellAbbrs = {
          gst  = "git status -sb";
          gco  = "git checkout";
          gl   = "git log --oneline -n 10";
          cpv  = "rsync -h --progress";
          cx   = "claude";
          cr   = "claude --resume";
          tn   = "cd ~/Projects/Technonomicon";
          gr   = "cd ~/Grimoire";
          pj   = "cd ~/Projects";
          pb   = "cd ~/Projects/Personal-Blog/content/posts";
          dl   = "cd ~/Downloads";
          bzip = "bzip3";
          book-dl   = "aria2c -x 16 -s 16";
          power-off = "bash /etc/scripts/clean-power-off.sh";
          restart   = "bash /etc/scripts/clean-reboot.sh";
          logout    = "sudo kill -9 -1";
          # evaluate here, build + switch on Akmon over the tailnet
          deploy-akmon = "nh os switch --hostname Akmon --target-host xin@akmon --build-host xin@akmon";
          # local switch; heavy builds still go to Akmon via distributedBuilds
          deploy-kvasir = "nh os switch --hostname Kvasir";
        };

        shellAliases = {
          cat  = "bat";
          # uutils cp/mv have a built-in progress bar (-g), GNU ones don't;
          # interactive only, scripts still get GNU coreutils
          cp   = "uutils-cp -r -g";
          mv   = "uutils-mv -g";
          dd   = "caligula burn";
          find = "fd -g -i";
          grep = "rg -i";

          rm   = "trash-put -v";
          rm-s = "shred -f";
          rm-r = "trash-restore";

          ll  = "eza --icons --oneline --group-directories-first --color auto";
          lx  = "eza --icons --oneline --group-directories-first --color auto --all";
          ls  = "eza --icons --oneline --group-directories-first --color auto --long";
          lsx = "eza --icons --oneline --group-directories-first --color auto --long --all";
          lld = "eza --icons --oneline --group-directories-first --color auto --tree";
          lxd = "eza --icons --oneline --group-directories-first --color auto --tree --all --ignore-glob='??????????????????????????????????????'";
          ld  = "eza --icons --oneline --only-dirs --color auto";
        };

        functions = {
          # prompt starts at the bottom of the window, with the home listing above it
          fish_greeting = ''
            string repeat -n 100 \n
            eza --icons --oneline --group-directories-first --color=always
          '';

          __tn_auto_ls = {
            onVariable = "PWD";
            body = "status is-interactive; and eza --icons --oneline --group-directories-first --color=always";
          };

          tnc = "cd ~/Projects/Technonomicon; and claude $argv";
          tnr = "cd ~/Projects/Technonomicon; and claude --resume $argv";
          grc = "cd ~/Grimoire; and claude $argv";
          grr = "cd ~/Grimoire; and claude --resume $argv";

          ca = ''
            clear
            string repeat -n 100 \n
          '';

          # yazi, then cd to wherever it was quit from
          y = ''
            set tmp (mktemp -t "yazi-cwd.XXXXXX")
            yazi $argv --cwd-file="$tmp"
            if read -z cwd < "$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
              builtin cd -- "$cwd"
            end
            command rm -f -- "$tmp"
          '';

          copypath = ''
            pwd | string collect | wl-copy
            echo "📋 Copied current path: $PWD"
          '';

          copyfile = ''
            if test (count $argv) -eq 0
              echo "Usage: copyfile <filename>"; return 1
            end
            wl-copy < $argv[1]; and echo "📋 Copied contents of $argv[1]"
          '';

          rg-menu  = "rg -i -- \"$argv[1]\" | fzf";
          rgx-menu = "rg -- \"$argv[1]\" | fzf";
          fd-menu  = "fd -i -- \"$argv[1]\" | fzf";
          fdx-menu = "fd --regex -- \"$argv[1]\" | fzf";

          monitor_command = ''
            if test (count $argv) -eq 0
              echo "Usage: monitor_command <command> [args...]"; return 1
            end
            command $argv &
            set -l pid $last_pid
            progress -mp $pid
            wait $pid
          '';

          pdf-split = ''
            if test (count $argv) -eq 0
              echo "Usage: pdf-split <filename.pdf>"; return 1
            end
            nix shell nixpkgs#ocamlPackages.cpdf -c cpdf -split-bookmarks 0 $argv[1] -utf8 -o '@B.pdf'
          '';

          # open a file in nvim in a fresh, detached ghostty window
          eon = ''
            if test (count $argv) -eq 0
              echo "Usage: eon <file>"; return 1
            end
            set -l file (path resolve $argv[1])
            ghostty --working-directory=(path dirname $file) -e nvim $file &>/dev/null &
            disown
          '';
        };

        plugins = [
          { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
          # desktop notification when a long command finishes unfocused
          { name = "done";     src = pkgs.fishPlugins.done.src; }
          { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
        ];
      };

      # syntax-highlighted git diffs (git diff/log -p/show, lazygit)
      programs.delta = {
        enable = true;
        enableGitIntegration = true;
        options = {
          navigate     = true;   # n/N jump between files
          line-numbers = true;
        };
      };

      # `tldr <cmd>`: a handful of examples instead of the whole man page
      programs.tealdeer = {
        enable = true;
        settings.updates.auto_update = true;
      };

      # coloured man pages, via bat
      home.sessionVariables = {
        MANPAGER   = "sh -c 'col -bx | bat -l man -p'";
        MANROFFOPT = "-c";
        # carapace completes most commands; make its matching ignore case
        # like fish's own (`cat doc<Tab>` finds Documents)
        CARAPACE_MATCH = "1";
      };

      # Ctrl-R: fuzzy, SQLite-backed history shared live across every terminal.
      # Up stays fish's own prefix search.
      programs.atuin = {
        enable = true;
        enableFishIntegration = true;
        flags = [ "--disable-up-arrow" ];
        settings = {
          search_mode   = "fuzzy";
          filter_mode   = "global";
          style         = "compact";
          inline_height = 20;
          enter_accept  = false;
          update_check  = false;
        };
      };

      # `t foo` jumps, `ti` picks — z is an awkward reach on Colemak-DH
      programs.zoxide = {
        enable = true;
        enableFishIntegration = true;
        options = [ "--cmd" "t" ];
      };

      programs.carapace = {
        enable = true;
        enableFishIntegration = true;
      };

    };

    programs.starship = {
      enable = true;
      settings = {
        format = "$hostname$directory$nix_shell$git_branch$git_commit$git_state$git_status$cmd_duration\n$character";
        time.disabled = true;

        # only shown over ssh, so a remote shell never looks like a local one
        hostname = {
          ssh_only   = true;
          ssh_symbol = "";
          style      = "bold #a3be8c";   # nord14 green
          format     = "[$ssh_symbol$hostname]($style) ";
        };

        cmd_duration = {
          min_time = 3000;
          style = "#768390";
          format = "[took $duration]($style) ";
        };

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
      uutils-coreutils   # prefixed (uutils-cp, …) so GNU coreutils stays the default
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
      pciutils
      fastfetch
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
      usbutils
      bat
      sox
      aria2
      bzip3
      powertop
      # bitwarden-cli
      # bitwarden-desktop
      nvtopPackages.full
      sops
      presenterm
      frogmouth
      opentimestamps-client
      inotify-tools
    ];
  };
}
