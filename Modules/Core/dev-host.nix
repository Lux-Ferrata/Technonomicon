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
  in {
    # ── Chat / edit-selection / aider, loaded on demand ──────────────────
    # The first request after an idle spell wakes it (~10-20 s to load),
    # 30 idle minutes put it back to sleep. --fit gives it whatever VRAM
    # completion leaves; the MoE experts that don't fit run from RAM, which
    # is fine with only ~3B parameters active per token.
    imports = [
      (import ./_llama-ondemand.nix {
        inherit pkgs lib;
        name        = "llama-chat";
        description = "llama.cpp chat server (Qwen3-Coder-30B-A3B)";
        listen      = "0.0.0.0";           # firewall: tailscale0 only
        port        = 8011;
        backendPort = 18011;
        idle        = "30min";
        args = [
          "${config.services.llama-cpp.package}/bin/llama-server"
          "--model ${models.chat-30b-a3b}"
          "--alias chat"
          "--jinja"                        # Qwen3 chat template + tool calls
          "--ctx-size 32768 --parallel 1"
          "--flash-attn on"
          "--fit on --fit-target 512"      # leave 512 MiB of VRAM spare
        ];
      })
    ];


    # shells that outlive the ssh connection (Kvasir's `ak` reattaches);
    # socket-activated user daemon, with linger so it survives the last logout
    environment.systemPackages = [
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
    systemd.packages           = [ pkgs.shpool ];
    systemd.user.sockets.shpool.wantedBy = [ "sockets.target" ];
    users.users.xin.linger     = true;

    # Shells here are always remote, but ones started by shpool or the VS Code
    # server don't inherit SSH_CONNECTION, so starship's ssh-only hostname
    # would vanish. Show it unconditionally.
    programs.starship.settings.hostname.ssh_only = lib.mkForce false;

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
      allowedTCPPorts = [ 22000 8011 8012 ];
      allowedUDPPorts = [ 22000 ];
    };

    # ── Code completion (FIM) for the editor, on the GPU ─────────────────
    # The GPU is completion's: the biggest coder model that fits with its
    # context, always loaded, so suggestions stay instant. Kvasir reaches it
    # through its local proxy (Tn-dev-client), which falls back to a CPU
    # model when Akmon is away. Flags follow llama-vscode's FIM server.
    services.llama-cpp = {
      enable   = true;
      package  = pkgs.llama-cpp.override { cudaSupport = true; };
      settings = {
        host           = "0.0.0.0";        # firewall: tailscale0 only
        port           = 8012;
        model          = models.fim-14b;
        n-gpu-layers   = 99;
        flash-attn     = "on";
        batch-size     = 1024;
        ubatch-size    = 1024;
        # shared by llama-vscode's parallel requests; 16k covers its
        # prefix/suffix + extra-context chunks. 8-bit KV cache halves its
        # VRAM so the 14B fits whole.
        ctx-size       = 16384;
        cache-type-k   = "q8_0";
        cache-type-v   = "q8_0";
        cache-reuse    = 256;
      };
    };
    # the CUDA runtime maps writable+executable memory
    systemd.services.llama-cpp.serviceConfig.MemoryDenyWriteExecute = lib.mkForce false;
  };
}
