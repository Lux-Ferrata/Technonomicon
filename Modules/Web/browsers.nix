{ inputs, ... }: {
  flake.nixosModules.Tn-web-browsers = { pkgs, config, ... }: {

    networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];

    programs.chromium.enable = true;
    environment.systemPackages = [
      pkgs.bitwarden-cli
      pkgs.bemenu
      ((pkgs.brave.override {
        commandLineArgs = [
          "--enable-features=UseOzonePlatform"
          "--ozone-platform=wayland"
          "--disable-features=BraveNews,BraveRewards,BraveWallet,WebRtcAllowInputVolumeAdjustment"
          "--hide-crash-restore-bubble"
          "--password-store=basic"
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
      }))
    ];

    environment.etc."brave/policies/managed/default.json".text = builtins.toJSON {
      "PasswordManagerEnabled" = false;
      "AutofillAddressEnabled" = false;
      "AutofillCreditCardEnabled" = false;

      "BraveRewardsDisabled" = true;
      "BraveWalletDisabled" = true;
      "BraveVPNMode" = 0; # 0 = Disabled
      "TorDisabled" = true;
      "IPFSCompanionEnabled" = false;

      "RestoreOnStartup" = 5;

      "DefaultBrowserSettingEnabled" = false;
      "MetricsReportingEnabled" = false;
      "SearchSuggestEnabled" = false;

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
