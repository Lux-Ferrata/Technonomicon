# Pre-build every ~/Projects dev shell, so `direnv` / `nix develop` are
# instant (Kvasir: also with no network). Shared by Tn-dev-client and
# Tn-dev-host; returns home-manager's systemd.user { services; timers; }.
# nix-direnv roots what it builds under each project's .envrc's .direnv;
# flakes without an .envrc get a profile root under `roots`. `guard` runs
# first and may `exit 0` to skip the round.
{ pkgs, lib, roots, guard ? "" }: {
  services.prewarm-devshells = {
    Unit.Description = "Pre-build ~/Projects dev shells";
    Service = {
      Type     = "oneshot";
      Nice     = 19;
      IOSchedulingClass = "idle";
      Environment = [
        "DIRENV_CONFIG=/etc/direnv"
        "PATH=${lib.makeBinPath [ pkgs.nix pkgs.direnv pkgs.git pkgs.bash pkgs.coreutils pkgs.curl pkgs.gnugrep ]}"
      ];
      ExecStart = pkgs.writeShellScript "prewarm-devshells" ''
        ${guard}
        roots=${roots}; mkdir -p "$roots"
        for d in "$HOME"/Projects/*/; do
          name=$(basename "$d")
          [ "$name" = Technonomicon ] && continue
          if [ -f "$d/.envrc" ]; then
            echo "== $name (direnv)"
            direnv exec "$d" true || echo "   failed (not allowed, or the shell doesn't build)"
          elif [ -f "$d/flake.nix" ] && nix flake show "$d" --json 2>/dev/null | grep -q '"devShells"'; then
            echo "== $name (flake)"
            nix develop "$d" --profile "$roots/$name" -c true || echo "   failed"
          fi
        done
      '';
    };
  };
  timers.prewarm-devshells = {
    Unit.Description = "Pre-build ~/Projects dev shells";
    Timer = {
      OnBootSec        = "15min";
      OnUnitActiveSec  = "3h";
      Persistent       = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
