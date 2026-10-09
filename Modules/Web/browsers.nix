{ inputs, ... }: {
  flake.nixosModules.Tn-web-browsers = { pkgs, config, ... }: {

    # Replace `brave` globally so *every* launch path — systemPackages, the
    # PWA desktop entries in web-apps.nix, keybinds — goes through our wrapper.
    # The wrapper rewrites the profile's exit_type to "Normal" before each
    # launch, which is what actually kills the "Restore pages? Brave didn't
    # shut down correctly" bubble. The --hide-crash-restore-bubble flag alone
    # does not reliably suppress it in this Brave build.
    nixpkgs.overlays = [
      (final: prev: {
        brave = let
          braveBase = (prev.brave.override {
            commandLineArgs = [
              # Chromium honours only the LAST --enable-features and the last
              # --disable-features. nixpkgs' wrapper (make-brave.nix) passes
              # its own pair before these args, and its lists are let-bound,
              # so each list here must repeat nixpkgs' entries: dropping them
              # silently turned off VA-API video decode (every video on the
              # CPU) and re-enabled the decoder path that breaks it on Intel.
              "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations"
              "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,BraveNews,BraveRewards,BraveWallet,WebRtcAllowInputVolumeAdjustment"
              "--ozone-platform=wayland"
              "--hide-crash-restore-bubble"
              "--password-store=basic"
              # fcitx5 (Pinyin) over Wayland's text-input-v3
              "--enable-wayland-ime"
              "--wayland-text-input-version=3"
            ];
          }).overrideAttrs (oldAttrs: {
            postFixup = (oldAttrs.postFixup or "") + ''
              for target_dir in "$out/lib/brave" "$out/libexec/brave" "$out/opt/brave" "$out/usr/lib/brave-browser"; do
                if [ -d "$target_dir" ]; then
                  echo "Injecting initial_preferences into $target_dir"
                  echo '${builtins.toJSON { browser = { custom_chrome_frame = true; }; }}' > "$target_dir/initial_preferences"
                fi
              done
            '';
          });
        in prev.symlinkJoin {
          name = "brave";
          paths = [ braveBase ];
          nativeBuildInputs = [ prev.makeWrapper ];
          postBuild = ''
            rm "$out/bin/brave"
            makeWrapper "${braveBase}/bin/brave" "$out/bin/brave" \
              --run '
                for prefs in "$HOME"/.config/BraveSoftware/Brave-Browser/*/Preferences; do
                  [ -f "$prefs" ] || continue
                  ${prev.gnused}/bin/sed -i \
                    -e '"'"'s/"exit_type":"[^"]*"/"exit_type":"Normal"/g'"'"' \
                    -e '"'"'s/"exited_cleanly":false/"exited_cleanly":true/g'"'"' \
                    "$prefs"
                done
              '
          '';
        };
      })
    ];

    programs.chromium.enable = true;
    environment.systemPackages = [
      pkgs.bitwarden-cli
      pkgs.bemenu
      pkgs.microsoft-edge
      pkgs.brave
    ];

    environment.etc."brave/policies/managed/default.json".text = builtins.toJSON {
      "PasswordManagerEnabled" = false;
      "AutofillAddressEnabled" = false;
      "AutofillCreditCardEnabled" = false;

      # 0 = incognito available, 1 = disabled, 2 = forced.
      "IncognitoModeAvailability" = 1;

      "BraveRewardsDisabled" = true;
      "BraveWalletDisabled" = true;
      "BraveVPNMode" = 0; # 0 = Disabled
      "TorDisabled" = true;
      "IPFSCompanionEnabled" = false;

      "RestoreOnStartup" = 5;
      # Memory Saver: discard tabs left inactive for a while (they reload on
      # click), so long sessions don't keep every background page running.
      "HighEfficiencyModeEnabled" = true;

      "DefaultBrowserSettingEnabled" = false;
      "MetricsReportingEnabled" = false;
      "SearchSuggestEnabled" = false;
      # address-bar searches go to SearXNG on Akmon (Tn-searxng)
      "DefaultSearchProviderEnabled"   = true;
      "DefaultSearchProviderName"      = "SearXNG";
      "DefaultSearchProviderKeyword"   = "sx";
      "DefaultSearchProviderSearchURL" = "https://search.ironshark.org/search?q={searchTerms}";

      "ShowHomeButton" = false;
      "NewTabPageLocation" = "https://en.wikipedia.org/wiki/Special:Random";
      "HomepageLocation" = "https://en.wikipedia.org/wiki/Special:Random";
      "BraveNewTabWidgetsVisible" = false;
      "NewTabPageAllowedTypes" = [ "none" ];
      "ImagesForNewTabPageEnabled" = false;

      "ExtensionInstallForcelist" = [
        "eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx" # Dark Reader
        "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx" # Bitwarden
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" # uBlock Origin
        "blaaajhemilngeeffpbfkdjjoefldkok;https://clients2.google.com/service/update2/crx" # LeechBlock NG
        "hfjbmagddngcpeloejdejnfgbamkjaeg;https://clients2.google.com/service/update2/crx" # Vimium C
        "dndlcbaomdoggooaficldplkcmkfpgff;https://clients2.google.com/service/update2/crx" # New Tab, New Window
        "abnjjjimjlbgandfdmgggedmkamigpcp;https://clients2.google.com/service/update2/crx" # Monkey Brain
        "emhhlhigmokehndjjmgnailciakdmoba;https://clients2.google.com/service/update2/crx" # 101weiqiLocalizer
        "mnjggcdmjocbbbhaepdhchncahnbgone;https://clients2.google.com/service/update2/crx" # SponsorBlock
        "cjnmckjndlpiamhfimnnjmnckgghkjbl;https://clients2.google.com/service/update2/crx" # Competitive Companion
        # enhanced-h264ify: YouTube only. Kaby Lake has no AV1 (or VP8)
        # decoder, so by default this blocks VP8/VP9/AV1 and YouTube serves
        # H.264, which the GPU decodes (up to 1080p, the panel's size).
        "omkfmpieigblcllmkgbflkikinpkodlk;https://clients2.google.com/service/update2/crx"
      ];

      "URLBlocklist" = [
        "youtube.com/shorts*"
      ];

      "ExtensionSettings" = {
        "hfjbmagddngcpeloejdejnfgbamkjaeg" = {
          "policy_for_managed_users" = {
            "keyMappings" = ''
              unmapAll
              map <c-f> LinkHints.activateMode
              map <c-t> Vomnibar.activateInNewTab
              map <c-n> Vomnibar.activate
            '';
          };
        };
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" = {
          "policy_for_managed_users" = {
            "userFilters" = ''
              youtube.com/shorts$document
              youtube.com##ytd-rich-section-renderer:has(ytd-rich-shelf-renderer[is-shorts])
              youtube.com##ytd-reel-shelf-renderer
              youtube.com##[is-shorts]
            '';
          };
        };
      };
    };

  };
}
