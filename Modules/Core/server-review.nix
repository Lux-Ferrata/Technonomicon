{ inputs, ... }: {
  # Claude's own look at the server (_tn-health-review.sh), 05:40 daily when
  # something is new and always on Wednesdays (deep: 7-day trends). Its short
  # read tops the 06:00 report; it diagnoses new self-reported issues and
  # labels the config-fixable ones `overnight` for the overnight agent.
  # Claude runs as tn-health: journal + metrics read access, nothing else.
  flake.nixosModules.Tn-server-review = { config, lib, pkgs, ... }:
  let
    state = "/var/lib/tn-health";
    review = pkgs.writeShellApplication {
      name = "tn-health-review";
      runtimeInputs = with pkgs; [
        bash coreutils gawk gnugrep gnused jq curl util-linux procps findutils
        config.systemd.package config.boot.zfs.package claude-code
        config.tn.alerts.issuePackage
      ];
      text = builtins.readFile ./_tn-health-review.sh;
    };
  in {
    users.users.tn-health = {
      isSystemUser = true;
      group        = "tn-health";
      home         = state;
      extraGroups  = [ "systemd-journal" ];
    };
    users.groups.tn-health = {};

    systemd.tmpfiles.rules = [ "d ${state} 0750 tn-health tn-health -" ];
    environment.persistence."/persist".directories = [
      { directory = state; user = "tn-health"; group = "tn-health"; mode = "0750"; }
    ];
    environment.systemPackages = [ review ];

    systemd.services.tn-health-review = {
      description = "Claude's review of the server's health";
      after    = [ "network-online.target" ];
      wants    = [ "network-online.target" ];
      serviceConfig = {
        Type            = "oneshot";
        ExecStart       = "${review}/bin/tn-health-review";
        TimeoutStartSec = "45min";
      };
    };
    systemd.timers.tn-health-review = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "05:40";   # after the 05:30 upgrade, before the 06:00 report
    };
  };
}
