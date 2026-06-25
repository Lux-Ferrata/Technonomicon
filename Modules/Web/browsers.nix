{ inputs, ... }: {
  flake.nixosModules.Tn-web-browsers = { pkgs, config, ... }:
    let
      # Nyxt 4.0 — fill in URL + hash before enabling.
      # nyxt4 = pkgs.appimageTools.wrapType2 {
      #   pname   = "nyxt";
      #   version = "4.0.0";
      #   src = pkgs.fetchurl {
      #     url  = "TODO";
      #     hash = "sha256-TODO";
      #   };
      # };
    in {

    programs.chromium.enable = true;
    environment.systemPackages = [
      pkgs.chromium
      # nyxt4
      ((pkgs.brave.override {
        commandLineArgs = [
          "--ozone-platform=auto"
          "--disable-features=BraveNews,BraveRewards,BraveWallet,WebRtcAllowInputVolumeAdjustment"
          "--hide-crash-restore-bubble"
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
      "BraveVPNMode" = 0;
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
        "gfbliohnnapiefjpjlpjnehglfpaknnc;https://clients2.google.com/service/update2/crx"
        "eimadpbcbfnmbkopoojfekhnkhdbieeh;https://clients2.google.com/service/update2/crx"
        "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
        "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
        "dndlcbaomdoggooaficldplkcmkfpgff;https://clients2.google.com/service/update2/crx"
        "blaaajhemilngeeffpbfkdjjoefldkok;https://clients2.google.com/service/update2/crx"
      ];
    };

  };
}
