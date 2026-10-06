# A llama-server that only exists while it's being used: systemd listens on
# `port`, the first connection starts the server on `backendPort` (and waits
# until it answers), and a proxy hands requests through. After `idle` with
# no traffic the proxy exits and the server stops with it, freeing the
# RAM/VRAM. Returns NixOS config to merge in.
# `listen` is where clients connect (0.0.0.0 to serve the tailnet, with the
# firewall deciding who); the server itself only ever binds localhost.
{ pkgs, lib, name, description, port, backendPort, args
, listen ? "127.0.0.1", idle ? "30min", extra ? { } }:
let
  host = "127.0.0.1";
in {
  systemd.sockets.${name} = {
    wantedBy      = [ "sockets.target" ];
    listenStreams = [ "${listen}:${toString port}" ];
  };
  systemd.services.${name} = {
    description = "Wake-on-request proxy for ${description}";
    requires    = [ "${name}-server.service" ];
    after       = [ "${name}-server.service" ];
    serviceConfig = {
      ExecStart   = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${idle} ${host}:${toString backendPort}";
      DynamicUser = true;
    };
  };
  systemd.services."${name}-server" = {
    inherit description;
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      # args = [ llama-server binary, flags... ]
      ExecStart = lib.concatStringsSep " " (args ++ [ "--host ${host}" "--port ${toString backendPort}" ]);
      # only "started" once it answers, so the proxy never hands a request
      # to a server that's still loading
      ExecStartPost = pkgs.writeShellScript "${name}-wait" ''
        for _ in $(seq 240); do
          ${pkgs.curl}/bin/curl -sf http://${host}:${toString backendPort}/health >/dev/null && exit 0
          sleep 0.5
        done
        exit 1
      '';
      TimeoutStartSec = 180;
      DynamicUser     = true;
      PrivateTmp      = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      NoNewPrivileges = true;
    } // extra;
  };
}
