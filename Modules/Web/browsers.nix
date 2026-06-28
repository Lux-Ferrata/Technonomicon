{ inputs, ... }: {
  flake.nixosModules.Tn-web-browsers = { pkgs, config, ... }: {

    programs.chromium.enable = true;
    environment.systemPackages = [
      pkgs.qutebrowser
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

    home-manager.users.xin.home.file.".config/qutebrowser/config.py" = {
      source = ./_qutebrowser-config.py;
      force = true;
    };
    home-manager.users.xin.home.file.".local/share/qutebrowser/userscripts/qute-bitwarden" = {
      source = "${pkgs.qutebrowser}/share/qutebrowser/userscripts/qute-bitwarden";
      executable = true;
    };

    home-manager.users.xin.xdg.mimeApps.defaultApplications = {
      "text/html"              = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/http"  = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
    };

    environment.etc."brave/policies/managed/default.json".text = builtins.toJSON {
      "PasswordManagerEnabled" = false;
      "AutofillAddressEnabled" = false;
      "AutofillCreditCardEnabled" = false;

      "BraveRewardsDisabled" = true;
      "BraveWalletDisabled" = true;
      "BraveVPNMode" = 0; # 0 = Disabled
      "TorDisabled" = true;
      "IPFSCompanionEnabled" = false;

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
      ];
    };

  };
}
