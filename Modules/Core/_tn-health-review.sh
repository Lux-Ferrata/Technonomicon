# tn-health-review: Claude looks the server over before the 06:00 report
# (Tn-server-review). Runs as root to gather facts and apply results; Claude
# itself runs as the unprivileged tn-health user with read-only tools, no
# sudo and no forge token.
#
#   tn-health-review            05:40 daily: only when something is new since
#                               the last review (an issue opened or recurred,
#                               alerts firing, failed units); otherwise exits
#   tn-health-review --deep     Wednesday (automatic) or by hand: always runs,
#                               and also looks at 7-day trends
#   tn-health-review --force    run even when nothing is new
#
# Out:  $STATE/review.md        a short read for the top of the daily email
#       comments on the issues that need a diagnosis (tn-issue comment), and
#       the `overnight` label on those a config change would fix, so the
#       overnight agent drafts a PR (never merged or deployed by itself)

STATE=${TN_HEALTH_STATE:-/var/lib/tn-health}
ALERTS=${TN_ALERTS_STATE:-/var/lib/tn-alerts}
WORK=$STATE/work
LAST=$STATE/last-review
DIAGNOSED=$STATE/diagnosed
MAX_DIAGNOSE=5

deep=0 force=0
[ "$(date +%u)" = 3 ] && deep=1
for a in "$@"; do
  case $a in --deep) deep=1 ;; --force) force=1 ;; esac
done
[ $deep = 1 ] && force=1

now=$(date +%s)
last=$(cat "$LAST" 2>/dev/null || echo $((now - 86400)))
touch "$DIAGNOSED"
: > "$STATE/review.md"            # never show yesterday's read
rm -rf "$WORK"; mkdir -p "$WORK"

# ── facts ─────────────────────────────────────────────────────────────────
tn-issue list > "$WORK/issues.tsv" || true
awk -F'\t' -v s="$last" '$1 >= s' "$ALERTS/events.tsv" 2>/dev/null > "$WORK/events.tsv" || true
curl -sf -m 10 http://127.0.0.1:8880/api/v1/alerts \
  | jq -r '.data.alerts[] | select(.state == "firing")
           | "\(.labels.severity // "digest")\t\(.name)\t\(.annotations.summary // "")"' \
  > "$WORK/alerts.txt" 2>/dev/null || true
systemctl list-units --failed --no-legend --plain > "$WORK/failed.txt" || true

# issues never diagnosed, oldest first, a handful per run
: > "$WORK/needs-diagnosis.txt"
cut -f1 "$WORK/issues.tsv" | sort -n | while read -r n; do
  [ -n "$n" ] || continue
  grep -qx "$n" "$DIAGNOSED" && continue
  echo "$n" >> "$WORK/needs-diagnosis.txt"
done
sed -i "$((MAX_DIAGNOSE + 1)),\$d" "$WORK/needs-diagnosis.txt"
while read -r n; do tn-issue show "$n" > "$WORK/issue-$n.md" || true; done < "$WORK/needs-diagnosis.txt"

new=$(awk -F'\t' '$2 == "open" || $2 == "recur"' "$WORK/events.tsv" | wc -l)
if [ $force = 0 ] && [ "$new" -eq 0 ] && [ ! -s "$WORK/alerts.txt" ] \
   && [ ! -s "$WORK/failed.txt" ] && [ ! -s "$WORK/needs-diagnosis.txt" ]; then
  echo "nothing new since $(date -d "@$last" '+%a %H:%M'); no review"
  echo "$now" > "$LAST"
  exit 0
fi

# ── Claude ────────────────────────────────────────────────────────────────
trend=""
if [ $deep = 1 ]; then
  trend="This is the weekly deep review: besides the files, look at 7-day trends nothing has alerted on yet: memory growth per unit (tn_unit_memory_bytes), restarts (tn_unit_restarts_total), pool growth (tn_zpool_alloc_bytes), error volume in the journal, temperatures, SMART attributes, probe failures, job freshness. Use range queries (/api/v1/query_range) or *_over_time functions."
fi

prompt="You are reviewing the health of the NixOS home server $(uname -n) for its owner, who reads a short email at 06:00 and never looks at dashboards. Today is $(date '+%A %d %B %Y, %H:%M %Z').

Files in $WORK:
- issues.tsv: open self-reported issues (number, fingerprint, title)
- needs-diagnosis.txt: issue numbers to diagnose now; each one's text and comments are in issue-<N>.md
- events.tsv: alert pipeline events since the last review (time, kind, fingerprint, issue, title)
- alerts.txt: metric alerts firing now (severity, name, summary)
- failed.txt: failed systemd units

Investigate with read-only commands: journalctl, systemctl status/show/list-units, zpool status/list, df, free, and metrics via curl -s 'http://127.0.0.1:8428/api/v1/query?query=<PromQL>' (also /api/v1/query_range). Metric families: node_*, systemd_*, smartctl_*, nvidia_smi_*, probe_* (blackbox), nginx_http_* (per vhost), tn_unit_* (per-unit memory/CPU/restarts), tn_job_* (last success of scheduled jobs), tn_zpool_*, ALERTS. The configuration lives in the Forgejo repo xin/Technonomicon (NixOS flake, modules under Modules/ and Hosts/Akmon/); you cannot read or change it from here, and you cannot change the system.
$trend

Write exactly two files:
1. $WORK/review.md: at most 120 words of plain text (no headings, no markdown) for the top of today's email. Lead with what matters; say what is fine; end with what, if anything, the owner should do. If nothing is wrong, one sentence.
2. $WORK/triage.json: a JSON array with one object per issue in needs-diagnosis.txt:
   {\"issue\": N, \"comment\": \"<markdown: likely cause, the evidence (log lines, metric values), and the fix>\", \"fixable_in_config\": true|false}
   fixable_in_config is true only when a change to the NixOS configuration would fix it and the comment says which change. It is false for hardware, upstream bugs, one-off blips, and anything needing the owner's decision. An empty array when needs-diagnosis.txt is empty."

chown -R tn-health:tn-health "$WORK"
CLAUDE_CODE_OAUTH_TOKEN=$(cat /run/secrets/claude-oauth-token)
export CLAUDE_CODE_OAUTH_TOKEN
cd "$WORK" || exit 1
setpriv --reuid=tn-health --regid=tn-health --init-groups --reset-env -- \
  env HOME="$STATE" PATH="$PATH" CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
  claude -p "$prompt" --output-format text --add-dir "$WORK" \
    --allowedTools "Read,Write,Glob,Grep,Bash(journalctl:*),Bash(systemctl status:*),Bash(systemctl show:*),Bash(systemctl list-units:*),Bash(systemctl list-timers:*),Bash(zpool status:*),Bash(zpool list:*),Bash(df:*),Bash(free:*),Bash(curl -s http://127.0.0.1:8428/*),Bash(curl -s 'http://127.0.0.1:8428/*)" \
  > "$WORK/claude.log" 2>&1 || echo "claude exited $?" >> "$WORK/claude.log"

# ── apply ─────────────────────────────────────────────────────────────────
if [ -s "$WORK/review.md" ]; then
  head -c 2000 "$WORK/review.md" > "$STATE/review.md"
fi
if [ -s "$WORK/triage.json" ] && jq -e 'type == "array"' "$WORK/triage.json" >/dev/null 2>&1; then
  jq -c '.[]' "$WORK/triage.json" | while read -r t; do
    n=$(jq -r '.issue' <<<"$t")
    grep -qx "$n" "$WORK/needs-diagnosis.txt" || continue      # only what we asked about
    { echo "**Claude's diagnosis** ($(date '+%a %d %b %H:%M'), automated review)"; echo
      jq -r '.comment' <<<"$t"
    } > "$WORK/comment-$n.md"
    if tn-issue comment "$n" "$WORK/comment-$n.md"; then
      echo "$n" >> "$DIAGNOSED"
      if [ "$(jq -r '.fixable_in_config' <<<"$t")" = true ]; then
        tn-issue label "$n" overnight || true
      fi
    fi
  done
fi
echo "$now" > "$LAST"
echo "review done: $(wc -c < "$STATE/review.md") bytes of read, $(wc -l < "$WORK/needs-diagnosis.txt") issue(s) to diagnose"
