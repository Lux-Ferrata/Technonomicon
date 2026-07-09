{ ... }: {
  flake.nixosModules.Tn-email = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      # TUI email stack
      aerc
      notmuch
      isync
      msmtp
      # CalDAV calendar stack
      khal
      vdirsyncer
      calcurse
    ];
  };
}
