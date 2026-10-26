# A llama-server that only exists while it's being used: systemd listens on
# `port`, the first connection starts the server on `backendPort` (and waits
# until it answers), and a proxy hands requests through. After `idle` with
# no traffic the proxy exits and the server stops with it, freeing the
# RAM/VRAM. Returns NixOS config to merge in.
# `listen` is where clients connect (0.0.0.0 to serve the tailnet, with the
# firewall deciding who); the server itself only ever binds localhost.
# `healthPath` is polled until the server answers (llama-server: /health),
# for at most `wait` seconds.
# `server`: an existing unit to wake instead (e.g. a container's
# "podman-strata"); it must serve on backendPort, and gets the same
# stop-when-unneeded and wait-until-healthy treatment. `args` is then unused.
{ pkgs, lib, name, description, port, backendPort, args ? [ ]
, listen ? "127.0.0.1", idle ? "30min", extra ? { }, healthPath ? "/health"
, wait ? 120, server ? null }:
let
  host = "127.0.0.1";
  serverUnit = if server == null then "${name}-server" else server;
  waitHealthy = {
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      # only "started" once it answers, so the proxy never hands a request
      # to a server that's still loading
      ExecStartPost = pkgs.writeShellScript "${name}-wait" ''
        for _ in $(seq ${toString (wait * 2)}); do
          ${pkgs.curl}/bin/curl -sf http://${host}:${toString backendPort}${healthPath} >/dev/null && exit 0
          sleep 0.5
        done
        exit 1
      '';
      TimeoutStartSec = wait + 60;
    };
  };
in {
  systemd.sockets.${name} = {
    wantedBy      = [ "sockets.target" ];
    listenStreams = [ "${listen}:${toString port}" ];
  };
  systemd.services.${name} = {
    description = "Wake-on-request proxy for ${description}";
    requires    = [ "${serverUnit}.service" ];
    after       = [ "${serverUnit}.service" ];
    serviceConfig = {
      ExecStart   = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=${idle} ${host}:${toString backendPort}";
      DynamicUser = true;
    };
  };
  systemd.services.${serverUnit} = if server != null then waitHealthy else lib.recursiveUpdate waitHealthy {
    inherit description;
    serviceConfig = {
      # args = [ llama-server binary, flags... ]
      ExecStart = lib.concatStringsSep " " (args ++ [ "--host ${host}" "--port ${toString backendPort}" ]);
      DynamicUser     = true;
      PrivateTmp      = true;
      ProtectSystem   = "strict";
      ProtectHome     = true;
      NoNewPrivileges = true;
    } // extra;
  };
}
