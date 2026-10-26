{ inputs, ... }: {
  # Akmon's side of "Akmon is the dev box": persistent shell sessions,
  # synced projects, the editor server and code completion for Kvasir.
  # Client side: Tn-dev-client.
  flake.nixosModules.Tn-dev-host = { config, pkgs, lib, ... }:
  let
    sync   = import ./_sync.nix;
    models = pkgs.callPackage ./_models.nix { };
    home = "/srv/xin";          # fast/srv/xin: xin's synced data, survives the root wipe
    # folders still taking their first copy from Kvasir: receive-only, so a
    # half-filled tree here can never be sent back. Empty this once done.
    seeding = [ ];
    llama = pkgs.llama-cpp.override { cudaSupport = true; };

    # Completion back on request -- unless it's night mode (00:00-05:45,
    # Tn-overnight) or Strata holds the GPU. Strata Conflicts= with the FIM
    # units, both ways: starting the FIM socket under a running Strata would
    # stop Strata, so everything that brings FIM back goes through here.
    # --no-block: Strata's ExecStopPost calls this while it's still stopping.
    fimResume = pkgs.writeShellApplication {
      name = "llama-fim-resume";
      runtimeInputs = [ pkgs.coreutils config.systemd.package ];
      text = ''
        [ "$(date +%H%M)" -lt 0545 ] && exit 0
        systemctl is-active -q podman-strata.service && exit 0
        systemctl start --no-block llama-fim.socket
      '';
    };

    # Lend the GPU to a job: every model server stops (and can't be woken)
    # while CMD runs, then goes back to sleeping-until-asked. xin may do
    # this without sudo (polkit rule below).
    llamaUnits = [ "llama-fim.socket" "strata.socket" "whisper.socket"
                   "llama-fim.service" "strata.service" "whisper.service"
                   "llama-fim-server.service" "podman-strata.service" "whisper-server.service" ];
    gpuLend = pkgs.writeShellApplication {
      name = "gpu-lend";
      runtimeInputs = [ pkgs.coreutils config.hardware.nvidia.package.bin fimResume ];
      text = ''
        if [ $# -eq 0 ]; then
          echo "Usage: gpu-lend CMD [ARGS...]   run CMD with the local models off the GPU"
          nvidia-smi --query-gpu=memory.used,memory.total --format=csv
          exit 2
        fi
        systemctl stop ${lib.concatStringsSep " " llamaUnits}
        restore() {
          systemctl start strata.socket whisper.socket
          llama-fim-resume
        }
        trap restore EXIT
        echo "gpu-lend: local models stopped; $(nvidia-smi --query-gpu=memory.used --format=csv,noheader) of VRAM still in use" >&2
        "$@"
      '';
    };

    # ── Strata: the chat model ───────────────────────────────────────────
    # Qwen3.8-Flash-Next (125B MoE) on Strata (github.com/Niko1221/Strata),
    # a CPU+GPU engine: attention, KV cache and the hottest experts in VRAM,
    # the other experts pinned in RAM and computed on the CPU. Upstream's
    # image, pinned; it only sees its own dataset. Models, pack, tuning and
    # its preset live in /var/lib/strata (fast/strata, not snapshotted:
    # ~70 GB that can be downloaded again).
    #
    #   :8011 (nginx, adds the API key) -> strata.socket 127.0.0.1:18011
    #     -> podman-strata 127.0.0.1:28011
    #
    # Strata always wants a key once it listens beyond loopback (it does,
    # inside the container), so nginx adds it and clients send none.
    # Woken on request like the llama servers; it stops completion first
    # (Kvasir's completion then falls back to its local model) and brings
    # it back when it goes to sleep. First run, and after changing the
    # model: `strata-prepare`.
    strata = {
      image = "ghcr.io/niko1221/strata:0.2.3-cuda13@sha256:d39ca9fc583c5085dc66b857fbf3b3e3a9e256f692672d4061322d3bd468433a";
      data  = "/var/lib/strata";
      port  = 28011;
      # IQ2_XS: ~35.5 GB of experts pinned in RAM, the rest on the GPU
      env = {
        FAMILY   = "qwen";
        MODEL    = "IQ2_XS";
        CONTEXT  = "128k";
        KV       = "int8";
        PARALLEL = "1";
        VISION   = "off";
        # The service never tunes: tuning outlasts the start timeout, and an
        # inconclusive result ("busy PC") saves nothing, so every wake tuned
        # again and was killed. strata-prepare tunes; starts keep its result.
        TUNE     = "skip";
        # room for whisper (~1 GB) next to the expert cache
        STRATA_SET = "vram-reserve-mib=1800";
      };
      # the ARC shrinks to this while Strata holds its experts
      arcMax = 4 * 1024 * 1024 * 1024;
    };
    # The experts are pinned, so nothing can push them out: make room before
    # they load. The host's own ARC cap (Hosts/Akmon) is saved and put back.
    arcParam = "/sys/module/zfs/parameters/zfs_arc_max";
    arcSqueeze = pkgs.writeShellScript "strata-arc-squeeze" ''
      [ -e /run/strata-arc-max ] || cat ${arcParam} > /run/strata-arc-max
      echo ${toString strata.arcMax} > ${arcParam}
      # the ARC gives memory back over a few seconds
      for _ in $(seq 30); do
        size=$(${pkgs.gawk}/bin/awk '$1 == "size" { print $3 }' /proc/spl/kstat/zfs/arcstats)
        [ "$size" -le $(( ${toString strata.arcMax} + 512 * 1024 * 1024 )) ] && exit 0
        sleep 1
      done
      echo "ARC still at $size bytes; Strata may choose its slower low-RAM mode" >&2
    '';
    arcRestore = pkgs.writeShellScript "strata-arc-restore" ''
      if [ -e /run/strata-arc-max ]; then
        cat /run/strata-arc-max > ${arcParam}
        rm /run/strata-arc-max
      fi
    '';
    podman = "${config.virtualisation.podman.package}/bin/podman";
    strataPrepare = pkgs.writeShellApplication {
      name = "strata-prepare";
      runtimeInputs = [ pkgs.coreutils pkgs.curl config.systemd.package ];
      text = ''
        # Download, prepare and tune Strata's model (tens of minutes the
        # first time; an interrupted download continues), outside the
        # wake-on-request units so nothing times out. Ends once it serves.
        [ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
        systemctl stop strata.socket strata.service podman-strata.service llama-fim.socket llama-fim.service llama-fim-server.service
        systemctl start strata-data.service
        ${arcSqueeze}
        cleanup() {
          ${podman} stop -t 120 strata-prepare >/dev/null 2>&1 || true
          ${podman} rm -f strata-prepare >/dev/null 2>&1 || true
          ${arcRestore}
          systemctl start strata.socket
          ${fimResume}/bin/llama-fim-resume
        }
        trap cleanup EXIT
        ${podman} run -d --name strata-prepare --replace \
          ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-e ${k}=${lib.escapeShellArg v}") strata.env)} \
          --env-file ${config.sops.templates."strata.env".path} \
          ${lib.concatStringsSep " " strataOptions} \
          -p 127.0.0.1:${toString strata.port}:8080 -v ${strata.data}:/data \
          ${strata.image} >/dev/null
        ${podman} logs -f strata-prepare &
        until curl -sf http://127.0.0.1:${toString strata.port}/health >/dev/null; do
          ${podman} container exists strata-prepare && [ "$(${podman} inspect -f '{{.State.Running}}' strata-prepare)" = true ] \
            || { echo "strata-prepare: the container stopped (see above)" >&2; exit 1; }
          sleep 5
        done
        echo "strata-prepare: ready; stopping it again (the next request to :8011 wakes it)" >&2
      '';
    };
    strataOptions = [ "--device=nvidia.com/gpu=all" "--ulimit=memlock=-1:-1" "--shm-size=2g" ];
  in {
    imports = [
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "strata";
        description = "Strata (Qwen3.8-Flash-Next)";
        server      = "podman-strata";
        port        = 18011;               # nginx :8011 in front
        backendPort = strata.port;
        idle        = "30min";
        wait        = 600;                 # pinning ~35 GB takes a minute or two
      })

      # ── Tags and summaries for Karakeep: small, on the CPU ─────────────
      # So a saved bookmark never wakes Strata (and stops completion). No
      # VRAM: it never competes with completion or Strata.
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "llama-tagger";
        description = "llama.cpp tagging server (Qwen2.5-Coder-3B, CPU)";
        port        = 8016;
        backendPort = 18016;
        idle        = "10min";
        args = [
          "${pkgs.llama-cpp}/bin/llama-server"   # the CPU build (Kvasir's)
          "--model ${models.chat-3b}"
          "--alias chat"
          "--jinja --ctx-size 8192 --threads 8"
        ];
        extra = { Nice = 10; CPUWeight = 20; };
      })

      # ── Code completion (FIM) for the editor, on the GPU ───────────────
      # The biggest coder model that fits whole with its context. Loaded on
      # the first request and kept while you're working; after an idle hour
      # it unloads and the GPU is free for anything else (the next
      # suggestion then waits a few seconds for it). Kvasir reaches it
      # through its local proxy (Tn-dev-client), which falls back to a CPU
      # model when Akmon is away -- or while Strata has the GPU (it stops
      # completion, then brings it back). Flags follow llama-vscode's FIM
      # server.
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "llama-fim";
        description = "llama.cpp completion server (FIM)";
        listen      = "0.0.0.0";           # firewall: tailscale0 only
        port        = 8012;
        backendPort = 18012;
        idle        = "1h";
        args = [
          "${llama}/bin/llama-server"
          "--model ${models.fim-14b}"
          "--n-gpu-layers 99 --flash-attn on"
          "--batch-size 1024 --ubatch-size 1024"
          # shared by llama-vscode's parallel requests; 16k covers its
          # prefix/suffix + extra-context chunks. 8-bit KV cache halves its
          # VRAM so the 14B fits whole.
          "--ctx-size 16384 --cache-type-k q8_0 --cache-type-v q8_0"
          "--cache-reuse 256"
        ];
      })

      # ── Speech to text (Whisper), on the GPU, on demand ──────────────
      # `stt` (here and on Kvasir) posts audio to :8020; the first request
      # wakes the server (~1 GB of VRAM), 10 idle minutes put it to sleep.
      # --convert: any audio/video format in, via ffmpeg.
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "whisper";
        description = "whisper.cpp speech-to-text server (large-v3-turbo)";
        listen      = "0.0.0.0";           # firewall: tailscale0 only
        port        = 8020;
        backendPort = 18020;
        idle        = "10min";
        healthPath  = "/";
        args = [
          "${pkgs.whisper-cpp.override { cudaSupport = true; }}/bin/whisper-server"
          "--model ${models.whisper-turbo}"
          "--language auto --convert --threads 8"
        ];
        # --convert writes its temp WAV into the working directory
        extra = { WorkingDirectory = "/tmp"; };
      })
    ];
    systemd.services.whisper-server.path = [ pkgs.ffmpeg-headless ];

    # ── Strata (see the let block) ───────────────────────────────────────
    virtualisation.oci-containers.containers.strata = {
      inherit (strata) image;
      autoStart       = false;             # strata.socket wakes it
      ports           = [ "127.0.0.1:${toString strata.port}:8080" ];
      volumes         = [ "${strata.data}:/data" ];
      environment     = strata.env;
      environmentFiles = [ config.sops.templates."strata.env".path ];
      # no memory limit: Strata plans from the host's RAM
      extraOptions    = strataOptions;
    };
    sops.secrets.strata-api-key = { };
    sops.templates."strata.env".content = "API_KEY=${config.sops.placeholder.strata-api-key}\n";
    sops.templates."strata-auth.conf" = {
      owner   = "nginx";
      content = ''
        proxy_set_header Authorization "Bearer ${config.sops.placeholder.strata-api-key}";
        proxy_set_header x-api-key "${config.sops.placeholder.strata-api-key}";
      '';
    };
    systemd.services.podman-strata = {
      # completion off the GPU first; it comes back in ExecStopPost
      conflicts = [ "llama-fim.socket" "llama-fim.service" "llama-fim-server.service" ];
      after     = [ "llama-fim.socket" "llama-fim.service" "llama-fim-server.service" "strata-data.service" ];
      requires  = [ "strata-data.service" ];
      # (oci-containers' 120 s stop timeout is what Strata asks for)
      serviceConfig = {
        ExecStartPre = [ "${arcSqueeze}" ];
        ExecStopPost = [ "${arcRestore}" "${fimResume}/bin/llama-fim-resume" ];
        # on request only: a failed load waits for the next request
        Restart      = lib.mkForce "no";
      };
    };

    # its own dataset, outside fast/srv: no snapshots of re-downloadable
    # weights; a mounted dataset, so it survives the root wipe
    systemd.services.strata-data = {
      description = "Create Strata's dataset on the fast pool";
      after       = [ "zfs-mount.service" ];
      wantedBy    = [ "multi-user.target" ];
      path        = [ config.boot.zfs.package ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        zfs list fast/strata >/dev/null 2>&1 || zfs create \
          -o mountpoint=${strata.data} -o recordsize=1M -o compression=off fast/strata
      '';
    };

    # :8011 for the tailnet (firewall below) and this machine; adds the key
    services.nginx.virtualHosts.strata-api = {
      listen = [ { addr = "0.0.0.0"; port = 8011; } ];
      locations."/" = {
        proxyPass   = "http://127.0.0.1:18011";
        extraConfig = ''
          include ${config.sops.templates."strata-auth.conf".path};
          proxy_buffering    off;            # streamed tokens
          proxy_read_timeout 900s;           # a cold start, then a long answer
          proxy_send_timeout 900s;
        '';
      };
      extraConfig = "client_max_body_size 64m;";   # Claude Code's requests are big
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var units = ${builtins.toJSON llamaUnits};
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "xin" &&
            units.indexOf(action.lookup("unit")) >= 0)
          return polkit.Result.YES;
      });
    '';


    # shells that outlive the ssh connection (Kvasir's `ak` reattaches);
    # socket-activated user daemon, with linger so it survives the last logout
    environment.systemPackages = [
      gpuLend
      fimResume
      strataPrepare
      (pkgs.callPackage ./_stt.nix { })
      (pkgs.callPackage ./_tts.nix { })
      pkgs.shpool
      # Akmon has no editor of its own: inside a VSCodium remote terminal,
      # open in that window; anywhere else (`ak`), point back to Kvasir
      (pkgs.writeShellScriptBin "eo" ''
        if [ -n "''${VSCODE_IPC_HOOK_CLI:-}" ] && command -v codium >/dev/null; then
          exec codium "''${@:-.}"
        fi
        echo "eo: Akmon is headless -- detach (Ctrl-Space Ctrl-q) and run eo on Kvasir;" >&2
        echo "    it opens the window on Akmon from there." >&2
        exit 1
      '')
    ];
    # Kvasir's Akmon helpers (Tn-dev-client), as they behave when already
    # here, so the same commands work in an Akmon terminal: rb runs in
    # place (direnv is already active), ak attaches the same shpool
    # session locally, overnight-now starts the run directly. aku is a
    # binary here already (Tn-server-usage).
    home-manager.users.xin.programs.fish.functions = {
      rb = ''
        test (count $argv) -gt 0; or begin; echo "usage: rb <command...>"; return 1; end
        $argv
      '';
      ak = ''
        set -l name $argv[1]
        set -l dir $HOME
        set -l rel (string replace -- "$HOME/Projects/" "" $PWD)
        if test "$rel" != "$PWD"
          set dir $PWD
          test -z "$name"; and set name (string split -m1 / -- $rel)[1]
        end
        test -z "$name"; and set name main
        shpool attach -f -d $dir -- $name
      '';
      overnight-now = "systemctl --user start --no-block overnight; and echo 'started; follow with: journalctl --user -fu overnight'";
    };

    systemd.packages           = [ pkgs.shpool ];
    systemd.user.sockets.shpool.wantedBy = [ "sockets.target" ];
    users.users.xin.linger     = true;

    # Shells here are always remote, but ones started by shpool or the VS Code
    # server don't inherit SSH_CONNECTION, so starship's ssh-only hostname
    # would vanish. Show it unconditionally.
    programs.starship.settings.hostname.ssh_only = lib.mkForce false;

    # pushes to forgejo@akmon from shells here use the passphrase-less key
    # instead of Kvasir's forwarded agent, so they never ask for the PIN
    sops.secrets.akmon-ssh-key = { owner = "xin"; };
    programs.ssh.extraConfig = ''
      Host akmon
        IdentityFile ${config.sops.secrets.akmon-ssh-key.path}
        IdentitiesOnly yes
    '';

    # ── VSCodium server (Open Remote - SSH from Kvasir) ──────────────────
    # The server and marketplace extensions ship generic-linux binaries
    programs.nix-ld.enable = true;
    # server + extensions survive the root wipe (else a re-download per boot)
    environment.persistence."/persist".users.xin.directories = [
      ".vscodium-server"
      ".local/share/direnv"
    ];
    # Projects arrive from Kvasir, where their .envrc files were already
    # allowed; don't make each one be re-allowed here before `rb` works.
    programs.direnv.settings.whitelist.prefix = [ "/home/xin/Projects" ];

    # Dev shells ready before `rb`/`eo` first enters a project (Kvasir does
    # the same for its offline copy). Flakes without an .envrc root their
    # shell under ${home}: /home/xin is wiped on boot, the roots must not be.
    home-manager.users.xin.systemd.user = let
      prewarm = import ./_prewarm-devshells.nix {
        inherit pkgs lib;
        roots = "${home}/.cache/devshells";
      };
    in {
      services.prewarm-devshells = prewarm.services.prewarm-devshells;
      timers.prewarm-devshells   = prewarm.timers.prewarm-devshells;
    };

    # ── Syncthing hub (topology in _sync.nix) ────────────────────────────
    # Every synced folder lands in fast/srv/xin/<dir>. The dataset is made on
    # first boot rather than by hand; sanoid already snapshots fast/srv
    # recursively, so these copies double as versioned backups.
    systemd.services.srv-xin = {
      description = "Create xin's dataset on the fast pool";
      after       = [ "zfs-mount.service" ];
      wantedBy    = [ "multi-user.target" ];
      path        = [ config.boot.zfs.package ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        zfs list fast/srv/xin >/dev/null 2>&1 || zfs create fast/srv/xin
        install -d -o xin -g users -m 0750 ${home} ${home}/.syncthing \
          ${lib.concatMapStringsSep " " (f: "${home}/${f.akmon}") (lib.attrValues sync.folders)}
      '';
    };

    # same absolute path as on Kvasir, so error paths, compile_commands.json
    # and editor state mean the same thing on both machines. Not part of
    # local-fs.target: srv-xin.service runs after sysinit, so the default
    # Before=local-fs.target would be an ordering cycle.
    systemd.mounts = [{
      what      = "${home}/Projects";
      where     = "/home/xin/Projects";
      type      = "none";
      options   = "bind";
      requires  = [ "srv-xin.service" ];
      after     = [ "srv-xin.service" ];
      before    = [ "umount.target" ];
      conflicts = [ "umount.target" ];
      wantedBy  = [ "multi-user.target" ];
      unitConfig.DefaultDependencies = false;
    }];

    # Runs as xin (not a system user) because the synced files must be xin's
    # to edit. Config + index live on the pool, identity in sops.
    sops.secrets.syncthing-akmon-cert = { owner = "xin"; };
    sops.secrets.syncthing-akmon-key  = { owner = "xin"; };

    # GUI at https://sync.ironshark.org (user xin). The REST API scripts
    # (grimoire-snapshot, Kvasir's sync checks) use the API key and don't
    # need it.
    sops.secrets.syncthing-gui-password = { owner = "xin"; };
    tn.web.vhosts.sync = {
      port = lib.toInt (lib.last (lib.splitString ":" config.services.syncthing.guiAddress));
    };

    services.syncthing = {
      enable           = true;
      guiPasswordFile  = config.sops.secrets.syncthing-gui-password.path;
      dataDir          = lib.mkForce home;
      configDir        = "${home}/.syncthing";
      cert             = config.sops.secrets.syncthing-akmon-cert.path;
      key              = config.sops.secrets.syncthing-akmon-key.path;
      # only reached over the tailnet
      openDefaultPorts = lib.mkForce false;
      settings = {
        gui = {
          user = "xin";
          # the host check guards a password-less GUI against DNS rebinding;
          # this one has a password and is reached as sync.ironshark.org
          insecureSkipHostcheck = true;
        };
        options = {
          globalAnnounceEnabled = false;
          localAnnounceEnabled  = false;
          relaysEnabled         = false;
          urAccepted            = -1;
        };
        devices = {
          Kvasir = { id = sync.devices.Kvasir; addresses = [ "tcp://kvasir:22000" ]; };
          Phone  = { id = sync.devices.Phone; };
        };
        folders = lib.mapAttrs (id: f: {
          inherit id;
          inherit (f) label;
          path            = "${home}/${f.akmon}";
          devices         = [ "Kvasir" ] ++ (f.extraDevices or [ ]);
          type            = if f.mode == "backup" || lib.elem id seeding
                            then "receiveonly" else "sendreceive";
          fsWatcherDelayS = 1;
          ignorePatterns  = f.ignorePatterns or null;
        }) sync.folders;
      };
    };
    systemd.services.syncthing = {
      requires = [ "srv-xin.service" ];
      after    = [ "srv-xin.service" ];
    };
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [ 22000 8011 8012 8020 ];
      allowedUDPPorts = [ 22000 ];
    };
  };
}
