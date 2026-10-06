{ inputs, ... }: {
  # How hard is the server working? `aku` (here, or from Kvasir over ssh) is
  # one screen of CPU / memory / GPU / pools; a 5-minute log of the same
  # numbers feeds the weekly email's usage section (`tn-usage --week`).
  flake.nixosModules.Tn-server-usage = { config, pkgs, ... }:
  let
    tn-usage = pkgs.writeShellApplication {
      name = "tn-usage";
      runtimeInputs = with pkgs; [
        coreutils gawk gnused procps systemd
        config.boot.zfs.package
        config.hardware.nvidia.package.bin    # nvidia-smi
      ];
      text = builtins.readFile ./_tn-usage.sh;
    };
  in {
    environment.systemPackages = [
      tn-usage
      (pkgs.writeShellScriptBin "aku" ''exec ${tn-usage}/bin/tn-usage "$@"'')
    ];

    # /var/lib/tn-usage/usage.csv, world-readable so the CI runner's weekly
    # job can summarise it
    systemd.services.tn-usage-log = {
      description = "Record a usage sample (tn-usage --log)";
      serviceConfig = {
        Type               = "oneshot";
        ExecStart          = "${tn-usage}/bin/tn-usage --log";
        StateDirectory     = "tn-usage";
        StateDirectoryMode = "0755";
        UMask              = "0022";
        ProtectSystem      = "strict";
        ProtectHome        = true;
        PrivateTmp         = true;
        NoNewPrivileges    = true;
      };
    };
    systemd.timers.tn-usage-log = {
      wantedBy    = [ "timers.target" ];
      timerConfig = { OnCalendar = "*:0/5"; AccuracySec = "10s"; };
    };

    environment.persistence."/persist".directories = [ "/var/lib/tn-usage" ];
  };
}
