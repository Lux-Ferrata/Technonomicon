{ inputs, ... }: {
  # Alerts for headless hosts, mailed through Tn-server-mail's msmtp:
  #
  #   unit failures  every failed system service is queued, and one digest
  #                  goes out once failures stop arriving for 2 min (a deploy
  #                  that knocks over postgres + nginx + ... is one mail, not
  #                  nine). Units that failed mid-deploy and are healthy
  #                  again by then are not mailed, only noted in the daily
  #                  digest. A unit that keeps failing mails at most every 3 h.
  #   error bursts   every 10 min the journal is scanned for errors; the same
  #                  error (numbers/ids normalised away) repeating >= 30 times
  #                  in that window mails at once, at most every 6 h per error.
  #                  Catches services that are "running" but broken, which
  #                  never trip OnFailure (the CI runner 404ing for 12 h).
  #   daily digest   06:00: units that failed in the last day, every distinct
  #                  error the journal logged (with counts), what is failed
  #                  right now, and how the 05:30 auto-upgrade went. Not sent
  #                  when there is nothing to say.
  #
  # Errors = journal priority err or worse, plus info-level lines that say
  # level=error / ERROR / panic (plenty of daemons log errors to stderr).
  # Known noise goes in tn.alerts.ignore.
  flake.nixosModules.Tn-server-alerts = { config, lib, pkgs, ... }:
  let
    cfg  = config.tn.alerts;
    to   = "xin@ironshark.org";
    from = "homelab@ironshark.org";
    host = config.networking.hostName;
    dir  = "/var/lib/tn-alerts";         # queue, history, stamps, issue state (persisted)

    # one journal-JSON line in -> {u, k, m} out for each error line
    # (u = unit, k = message with the variable bits normalised, m = raw)
    errorFilter = pkgs.writeText "tn-alerts-filter.jq" ''
      select(.MESSAGE | type == "string")
      | select(((.PRIORITY // "6") | tonumber) <= 3
               or (.MESSAGE | test("level=(error|fatal)|\\b(ERROR|FATAL|PANIC|CRITICAL)\\b|panic:|\\[(error|crit|alert|emerg)\\]")))
      | (._SYSTEMD_UNIT // .SYSLOG_IDENTIFIER // "?") as $u
      | select($u | test("^(notify-failure@|tn-alerts)") | not)
      | select("\($u)\t\(.MESSAGE)" | test($ignore) | not)
      | { u: $u,
          m: .MESSAGE[0:300],
          k: (.MESSAGE
              | gsub("time=\"[^\"]*\""; "")
              | gsub("<[^>]*>"; "<>")
              | gsub("\\b(?=[A-Za-z_]*[0-9])[A-Za-z0-9_+/=-]{6,}\\b"; "#")
              | gsub("[0-9]+"; "#")
              | .[0:160]) }
    '';
    # slurped {u,k,m} -> "count<TAB>unit<TAB>key<TAB>last raw message", busiest first
    errorGroups = pkgs.writeText "tn-alerts-groups.jq" ''
      group_by([.u, .k])
      | map({ n: length, u: .[0].u, k: .[0].k, m: .[-1].m })
      | map(select(.n >= $min))
      | sort_by(-.n)[]
      | "\(.n)\t\(.u)\t\(.k)\t\(.m)"
    '';
    ignoreRe = if cfg.ignore == [] then "(?!)" else lib.concatStringsSep "|" cfg.ignore;

    # errors SINCE MIN -> grouped lines (see errorGroups)
    scanErrors = pkgs.writeShellScript "tn-alerts-scan" ''
      journalctl --since "$1" -o json --no-pager \
        | jq -c --arg ignore ${lib.escapeShellArg ignoreRe} -f ${errorFilter} \
        | jq -rs --argjson min "$2" -f ${errorGroups}
    '';

    # mail SUBJECT, body on stdin; plain text plus an HTML copy in a
    # monospace block (Gmail shows plain text in a proportional font, which
    # wrecks the columns)
    mail = pkgs.writeShellScript "tn-alerts-mail" ''
      body=$(cat)
      b="tn-$$-$RANDOM"
      { echo "To: ${to}"
        echo "From: ${host} <${from}>"
        echo "Subject: [${host}] $1"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/alternative; boundary=\"$b\""
        echo
        echo "--$b"
        echo "Content-Type: text/plain; charset=utf-8"
        echo
        printf '%s\n' "$body"
        echo "--$b"
        echo "Content-Type: text/html; charset=utf-8"
        echo
        echo '<pre style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;line-height:1.35;white-space:pre-wrap">'
        printf '%s\n' "$body" | ${pkgs.gnused}/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
        echo '</pre>'
        echo "--$b--"
      } | /run/wrappers/bin/sendmail -t
    '';

    tn-issue = pkgs.writeShellApplication {
      name = "tn-issue";
      runtimeInputs = with pkgs; [ coreutils curl jq gawk findutils config.systemd.package ];
      text = builtins.readFile ./_tn-issue.sh;
    };
    issue = "${tn-issue}/bin/tn-issue";

    path = with pkgs; [ config.systemd.package coreutils gnugrep gnused gawk jq findutils curl ];

    # our own units: a broken mail setup must not trigger more mail
    alertUnits = [ "notify-failure@" "tn-alerts-flush" "tn-alerts-burst" "tn-alerts-daily"
                   "tn-alerts-rules" "tn-alerts-sweep" ];
  in {
    options.tn.alerts.issuePackage = lib.mkOption {
      type     = lib.types.package;
      default  = tn-issue;
      readOnly = true;
      description = "tn-issue, for other modules (Tn-server-review).";
    };

    options.tn.alerts.reportCommand = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
      default = null;
      description = "tn-report (Tn-server-reports): the daily digest becomes a chart email.";
    };

    options.tn.alerts.ignore = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Regexes (jq/Oniguruma) for journal errors that are known noise; matched
        against "<unit>\t<message>".
      '';
    };

    config = {
      tn.alerts.ignore = [
        # every NixOS dbus reload; harmless
        "Ignoring duplicate name '[^']*' in service file"
        # karakeep's headless Chromium has no dbus/GPU/Google account; harmless
        "^karakeep-browser\\.service\t.*:ERROR:(dbus/|google_apis/|services/on_device_model/)"
      ];

      systemd.tmpfiles.rules = [ "d ${dir} 0700 root root -" ];
      environment.persistence."/persist".directories = [ dir ];
      environment.systemPackages = [ tn-issue ];

      # ---- unit failures: record, then let the flusher batch them ---------
      systemd.services."notify-failure@" = {
        description = "Queue an alert about failed unit %i";
        serviceConfig.Type = "oneshot";
        # a restart-looping unit triggers this every few seconds; the flusher
        # batches, so systemd's start limit must not drop any of them
        unitConfig.StartLimitIntervalSec = 0;
        scriptArgs = "%i";
        inherit path;
        script = ''
          deploy=0
          if systemctl list-units --no-legend --state=active,activating \
               '*switch-to-configuration*' | grep -q .; then deploy=1; fi
          printf '%s\t%s\t%s\n' "$(date +%s)" "$1" "$deploy" >> ${dir}/queue
          systemctl start --no-block tn-alerts-flush.service
        '';
      };

      systemd.services.tn-alerts-flush = {
        description = "Mail one digest of queued unit failures";
        serviceConfig.Type = "oneshot";
        inherit path;
        script = ''
          q=${dir}/queue
          while sleep 30; do
            [ -s "$q" ] || exit 0
            now=$(date +%s)
            newest=$(tail -n1 "$q" | cut -f1)
            oldest=$(head -n1 "$q" | cut -f1)
            # wait for 2 quiet minutes, but never sit on news for > 15
            if [ $((now - newest)) -lt 120 ] && [ $((now - oldest)) -lt 900 ]; then continue; fi
            mv "$q" "$q.sending"

            failed=() recovered=()
            for unit in $(cut -f2 "$q.sending" | awk '!seen[$0]++'); do
              n=$(awk -F'\t' -v u="$unit" '$2 == u' "$q.sending" | wc -l)
              alldeploy=$(awk -F'\t' -v u="$unit" '$2 == u && $3 == 0 {x=1} END {print x ? 0 : 1}' "$q.sending")
              stamp=${dir}/mailed-$unit
              if systemctl is-failed --quiet "$unit"; then outcome=failed
              elif [ "$alldeploy" = 1 ]; then outcome=deploy-recovered
              else outcome=recovered; fi
              if [ "$outcome" != deploy-recovered ] && [ -n "$(find "$stamp" -mmin -180 2>/dev/null)" ]; then
                outcome=repeat
              fi
              printf '%s\t%s\t%s\t%s\n' "$now" "$unit" "$outcome" "$n" >> ${dir}/history
              case $outcome in
                failed)    failed+=("$unit");    touch "$stamp" ;;
                recovered) recovered+=("$unit"); touch "$stamp" ;;
              esac
            done
            first=$(head -n1 "$q.sending" | cut -f1)
            rm "$q.sending"

            for u in "''${failed[@]}"; do
              { systemctl status --full --no-pager "$u" || true
                echo
                journalctl -u "$u" --since "@$((first - 120))" -n 60 --no-pager || true
              } > ${dir}/body 2>&1
              ${issue} report "unit:$u" urgent "$u failed" ${dir}/body || true
            done
            [ $((''${#failed[@]} + ''${#recovered[@]})) -gt 0 ] || continue

            if [ ''${#failed[@]} -gt 0 ]; then
              subject="''${#failed[@]} failed: ''${failed[*]}"
              if [ ''${#recovered[@]} -gt 0 ]; then subject="$subject (+''${#recovered[@]} recovered)"; fi
            else
              subject="''${recovered[*]} failed, since recovered"
            fi
            subject=$(echo "$subject" | sed 's/\.service//g')

            {
              for u in "''${failed[@]}";    do echo "STILL FAILED  $u"; done
              for u in "''${recovered[@]}"; do echo "recovered     $u"; done
              for u in "''${failed[@]}"; do
                echo; echo "======== $u"
                systemctl status --full --no-pager "$u" || true
                echo
                journalctl -u "$u" --since "@$((first - 120))" -n 60 --no-pager || true
              done
              for u in "''${recovered[@]}"; do
                echo; echo "======== $u (recovered)"
                journalctl -u "$u" --since "@$((first - 120))" -n 30 --no-pager || true
              done
            } 2>&1 | ${mail} "$subject"
          done
        '';
      };

      # every service gets OnFailure=notify-failure@...; our own units clear
      # it again (a same-named drop-in in the unit's own dir wins)
      systemd.packages = [
        (pkgs.runCommand "notify-failure-dropins" {} ''
          mkdir -p $out/etc/systemd/system/service.d
          cat > $out/etc/systemd/system/service.d/90-notify-failure.conf <<EOF
          [Unit]
          OnFailure=notify-failure@%n.service
          EOF
          for u in ${lib.concatStringsSep " " alertUnits}; do
            mkdir -p $out/etc/systemd/system/$u.service.d
            printf '[Unit]\nOnFailure=\n' > $out/etc/systemd/system/$u.service.d/90-notify-failure.conf
          done
        '')
      ];

      # ---- error bursts --------------------------------------------------
      systemd.services.tn-alerts-burst = {
        description = "Mail about errors repeating in the journal";
        serviceConfig.Type = "oneshot";
        inherit path;
        script = ''
          ${scanErrors} -10min 30 | while IFS=$'\t' read -r n unit key msg; do
            stamp=${dir}/burst-$(printf '%s\t%s' "$unit" "$key" | md5sum | cut -c1-16)
            if [ -n "$(find "$stamp" -mmin -360 2>/dev/null)" ]; then
              ${issue} report "burst:''${stamp##*/burst-}" urgent "''${unit%.service} logs the same error over and over" || true
              continue
            fi
            touch "$stamp"
            {
              echo "$unit logged this error $n times in the last 10 minutes:"
              echo
              echo "  $msg"
              echo
              echo "(no repeat mail about this error for 6 h)"
              echo
              systemctl status --full --no-pager "$unit" 2>/dev/null | head -n 15
              echo
              journalctl -u "$unit" -n 30 --no-pager 2>/dev/null
            } 2>&1 | tee ${dir}/body | ${mail} "''${unit%.service}: same error x$n in 10 min"
            ${issue} report "burst:''${stamp##*/burst-}" urgent "''${unit%.service} logs the same error over and over" ${dir}/body || true
          done
        '';
      };
      systemd.timers.tn-alerts-burst = {
        wantedBy  = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/10";
      };

      # ---- metric alerts (vmalert, Tn-server-metrics) ---------------------
      # firing -> issue; urgent ones also mail (once per alert per 6 h);
      # gone -> resolve (the sweep closes the issue after 24 h)
      systemd.services.tn-alerts-rules = {
        description = "Turn firing vmalert alerts into mail and issues";
        serviceConfig.Type = "oneshot";
        path = path ++ [ pkgs.diffutils ];
        script = ''
          alerts=$(curl -sf -m 10 http://127.0.0.1:8880/api/v1/alerts) || exit 0
          printf '%s' "$alerts" | jq -c '.data.alerts[] | select(.state == "firing")
            | . + { lk: ([.labels | to_entries[] | select(.key != "severity" and .key != "alertstate")
                          | "\(.key)=\(.value)"] | sort | join(",")) }' > ${dir}/rules.now || true
          : > ${dir}/rules.active.new

          while read -r a; do
            name=$(jq -r .name <<<"$a")
            fp="rule:$name:$(jq -r .lk <<<"$a" | md5sum | cut -c1-12)"
            echo "$fp" >> ${dir}/rules.active.new
            sev=$(jq -r '.labels.severity // "digest"' <<<"$a")
            summary=$(jq -r '.annotations.summary // .name' <<<"$a")
            jq -r '"alert: \(.name)\nsince: \(.activeAt)\nvalue: \(.value)\nlabels: \(.labels | to_entries | map("\(.key)=\(.value)") | join(" "))\nexpr:  \(.expression)"' \
              <<<"$a" > ${dir}/body
            if [ "$sev" = urgent ]; then
              stamp=${dir}/rule-$(printf '%s' "$fp" | md5sum | cut -c1-16)
              if [ -z "$(find "$stamp" -mmin -360 2>/dev/null)" ]; then
                touch "$stamp"
                { cat ${dir}/body; echo; echo "Graphs and history: ask Claude, or https://metrics.${config.tn.web.domain or "ironshark.org"}/"; } \
                  | ${mail} "$summary"
              fi
            fi
            ${issue} report "$fp" "$sev" "$summary" ${dir}/body || true
          done < ${dir}/rules.now

          # alerts that stopped firing
          if [ -f ${dir}/rules.active ]; then
            sort -u -o ${dir}/rules.active.new ${dir}/rules.active.new
            comm -23 ${dir}/rules.active ${dir}/rules.active.new | while read -r fp; do
              ${issue} resolve "$fp" || true
            done
          fi
          sort -u -o ${dir}/rules.active.new ${dir}/rules.active.new
          mv ${dir}/rules.active.new ${dir}/rules.active
        '';
      };
      systemd.timers.tn-alerts-rules = {
        wantedBy  = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/2";
      };

      systemd.services.tn-alerts-sweep = {
        description = "Close self-reported issues that are resolved";
        serviceConfig = { Type = "oneshot"; ExecStart = "${issue} sweep"; };
      };
      systemd.timers.tn-alerts-sweep = {
        wantedBy  = [ "timers.target" ];
        timerConfig.OnCalendar = "hourly";
      };

      # ---- daily digest --------------------------------------------------
      systemd.services.tn-alerts-daily = {
        description = "Mail the daily error digest";
        serviceConfig.Type = "oneshot";
        inherit path;
        script = ''
          hist=${dir}/history
          [ -f "$hist" ] && mv "$hist" "$hist.daily"
          errors=$(${scanErrors} -24h 1)
          failednow=$(systemctl list-units --failed --no-legend --plain | awk '{print $1}')
          upgrade=$(systemctl show nixos-upgrade -p Result -p ExecMainExitTimestamp --value 2>/dev/null | paste -sd' ')

          firing=$(jq -r '"\(.labels.severity // "digest")\t\(.annotations.summary // .name)"' ${dir}/rules.now 2>/dev/null | sort || true)
          since=$(( $(date +%s) - 86400 ))
          events=$(awk -F'\t' -v s="$since" '$1 >= s && ($2 == "open" || $2 == "close" || $2 == "capped")' ${dir}/events.tsv 2>/dev/null || true)
          openissues=$(${issue} list 2>/dev/null || true)

          # errors seen on two days running become issues (err:<hash>)
          printf '%s\n' "$errors" | awk -F'\t' 'NF >= 3 && $1 >= 3 { print $2 "\t" $3 }' | sort -u > ${dir}/errkeys.today
          if [ -f ${dir}/errkeys.prev ]; then
            comm -12 ${dir}/errkeys.prev ${dir}/errkeys.today | while IFS=$'\t' read -r unit key; do
              line=$(printf '%s\n' "$errors" | awk -F'\t' -v u="$unit" -v k="$key" '$2 == u && $3 == k' | head -n1)
              n=$(cut -f1 <<<"$line"); msg=$(cut -f4 <<<"$line")
              { echo "$n times in the last 24 h (and yesterday too). Latest:"; echo; echo "$msg"; echo
                journalctl -u "$unit" --since -24h --no-pager 2>/dev/null | grep -F -- "''${msg:0:60}" | tail -n 5 || true
              } > ${dir}/body
              ${issue} report "err:$(printf '%s\t%s' "$unit" "$key" | md5sum | cut -c1-16)" digest \
                "''${unit%.service}: ''${msg:0:90}" ${dir}/body || true
            done
          fi
          mv ${dir}/errkeys.today ${dir}/errkeys.prev

          # with the chart report this goes out every day (silence = Akmon down);
          # the plain-text fallback keeps quiet days quiet
          ${lib.optionalString (cfg.reportCommand == null) ''
            [ -z "$errors$failednow$firing$events" ] && [ ! -s "$hist.daily" ] && { rm -f "$hist.daily"; exit 0; }
          ''}

          nerr=$(printf '%s' "$errors" | grep -c . || true)
          {
            echo "Auto-upgrade: $upgrade"
            echo
            echo "== Failed right now"
            echo "''${failednow:-none}"
            echo
            echo "== Alerts firing now"
            if [ -n "$firing" ]; then printf '%s\n' "$firing" | sed 's/^/  /'; else echo "  none"; fi
            echo
            echo "== Issues (https://git.ironshark.org/xin/agent-tasks/issues?labels=akmon-health)"
            if [ -n "$events" ]; then
              printf '%s\n' "$events" | awk -F'\t' '{ printf "  %-7s #%s %s\n", $2, $4, $5 }'
            fi
            if [ -n "$openissues" ]; then
              echo "  open now:"
              printf '%s\n' "$openissues" | awk -F'\t' '{ printf "    #%s %s\n", $1, $3 }'
            elif [ -z "$events" ]; then echo "  none"; fi
            echo
            echo "== Unit failures since the last digest"
            if [ -s "$hist.daily" ]; then
              awk -F'\t' '{ k = $2 " (" $3 ")"; c[k] += $4 } END { for (k in c) printf "  %4d x %s\n", c[k], k }' "$hist.daily" | sort -rn
              echo "  (deploy-recovered = failed during a deploy, fine again afterwards)"
            else echo "  none"; fi
            echo
            echo "== Distinct errors in the journal, last 24 h ($nerr)"
            printf '%s\n' "$errors" | head -n 40 | while IFS=$'\t' read -r n unit key msg; do
              [ -n "$n" ] || continue
              printf '%6d  %s\n        %s\n' "$n" "''${unit%.service}" "$msg"
            done
            if [ "$nerr" -gt 40 ]; then echo "  ... and $((nerr - 40)) more"; fi
            echo
            echo "Known noise is filtered by tn.alerts.ignore (Modules/Core/server-alerts.nix)."
          } > ${dir}/daily.txt 2>&1
          subject="daily: $( [ -n "$failednow" ] && echo "$(echo "$failednow" | wc -l) failed, " )$nerr distinct errors"
          ${if cfg.reportCommand == null then ''
            ${mail} "$subject" < ${dir}/daily.txt
          '' else ''
            nopen=$(printf '%s' "$openissues" | grep -c . || true)
            ${cfg.reportCommand} daily --text ${dir}/daily.txt --review /var/lib/tn-health/review.md \
              --open-issues "$nopen" \
              || ${mail} "$subject (charts failed)" < ${dir}/daily.txt
          ''}
          rm -f "$hist.daily"
        '';
      };
      systemd.timers.tn-alerts-daily = {
        wantedBy  = [ "timers.target" ];
        timerConfig.OnCalendar = "06:00";   # after the 05:30 auto-upgrade
      };
    };
  };
}
