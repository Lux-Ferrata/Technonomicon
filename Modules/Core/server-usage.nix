{ inputs, ... }: {
  # How hard is the server working? `aku` (here, or from Kvasir over ssh) is
  # btop live, GPU included; `aku -s` is a one-screen snapshot with the
  # pools and llama servers. A 5-minute log of the snapshot numbers feeds
  # the weekly email's usage section (`tn-usage --week`).
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
      (pkgs.writeShellScriptBin "aku" ''
        case "''${1:-}" in
          "")       exec btop ;;
          -s)       shift; exec ${tn-usage}/bin/tn-usage "$@" ;;
          *)        exec ${tn-usage}/bin/tn-usage "$@" ;;
        esac
      '')
    ];

    # btop finds NVML (the GPU box) through the driver runpath only when
    # built with CUDA support; that's a tiny rebuild of btop alone
    nixpkgs.overlays = [ (_: prev: { btop = prev.btop.override { cudaSupport = true; }; }) ];

    # Kvasir's btop setup minus the desktop theme (no nix-colors here; btop's
    # own nord is the same palette). Read-only, so btop can't rewrite it.
    home-manager.users.xin.xdg.configFile."btop/btop.conf".text = ''
      color_theme = "nord"
      theme_background = False
      rounded_corners = True
      graph_symbol = braille
      vim_keys = True
      # fits a short terminal (~24 rows): the GPU lives in the CPU box
      # (stats line + graph under the CPU graph) instead of its own box.
      # `p` cycles presets; preset 1 adds the GPU and net boxes when tall.
      shown_boxes = "cpu mem proc"
      show_gpu_info = "On"
      cpu_graph_lower = "gpu-totals"
      presets = "cpu:0:default,gpu0:0:default,mem:0:default,net:0:default,proc:0:default"
      update_ms = 1000
      proc_sorting = "cpu lazy"
      temp_scale = "celsius"
      zfs_arc_cached = True
      # /srv is a native ZFS mount, not in fstab: read the live mounts, and
      # keep the impermanence bind mounts out of the list
      use_fstab = False
      disks_filter = "/ /nix /persist /srv"
      net_iface = "tailscale0"
      draw_clock =
    '';

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
