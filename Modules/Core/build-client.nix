{ inputs, ... }: {
  # Offload builds to Akmon and pull from its cache when it's reachable over
  # the tailnet; everything quietly falls back to local builds and
  # cache.nixos.org when it isn't. Server side: Tn-build-host.
  flake.nixosModules.Tn-build-client = { config, ... }: {

    # root's key for the builder account; separate from xin's (passphrase)
    sops.secrets.nix-builder-ssh-key = {};

    nix.distributedBuilds = true;
    nix.buildMachines = [{
      hostName          = "akmon";
      protocol          = "ssh-ng";
      sshUser           = "nix-builder";
      sshKey            = config.sops.secrets.nix-builder-ssh-key.path;
      system            = "x86_64-linux";
      maxJobs           = 12;
      speedFactor       = 4;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    }];

    nix.settings = {
      # let Akmon download inputs itself instead of copying them from here
      builders-use-substitutes = true;
      substituters             = [ "http://akmon:5000" ];
      trusted-public-keys      = [ "akmon-cache-1:Xm7eg+Ac0nEiHJrzV1+SJx+1gFKyMRThqevh9pv8B+Y=" ];
      # Akmon offline: give up on it fast and carry on locally
      connect-timeout          = 5;
      fallback                 = true;
    };

    # root (the nix daemon) has never seen Akmon's host key
    programs.ssh.knownHosts.akmon = {
      hostNames = [ "akmon" "akmon.tail607809.ts.net" "100.122.244.58" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPZ5Yp2R4OWVPfvW7DSQiLnTwX+IS5AbnYQ1NP9ZRKzk";
    };
    programs.ssh.extraConfig = ''
      Host akmon
        ConnectTimeout 5
    '';
  };
}
