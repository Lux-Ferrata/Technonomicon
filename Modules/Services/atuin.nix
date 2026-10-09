{ inputs, ... }: {
  # Atuin sync server at https://atuin.ironshark.org, on the shared Postgres.
  # Shell history is end-to-end encrypted by the clients (both machines hold
  # the same key), so Ctrl-R shows one history on Kvasir and Akmon; Kvasir's
  # offline history goes up when it next reaches Akmon. Client side: Tn-shell.
  flake.nixosModules.Tn-atuin = { ... }:
  let
    port = 8888;
  in {
    services.atuin = {
      enable = true;
      host = "127.0.0.1";
      inherit port;
      # only xin's account; open just long enough to `atuin register` it
      openRegistration = true;
      database.createLocally = true;
    };

    tn.web.vhosts.atuin = { inherit port; maxBody = "50m"; };
  };
}
