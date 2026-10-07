# tn-issue: the server reports its own problems as Forgejo issues (Tn-server-alerts).
#   tn-issue report FP SEVERITY TITLE [BODY-FILE]
#                       open an issue, or comment on it again (at most every 6 h)
#   tn-issue resolve FP mark fixed; `sweep` closes it once it stays fixed for 24 h
#   tn-issue sweep      close what is resolved: unit:* once the unit is no longer
#                       failed, rule:* once vmalert stops firing (the poller calls
#                       resolve), burst:* and err:* once not seen for 48 h
#   tn-issue list       open health issues: number <TAB> fingerprint <TAB> title
#   tn-issue show NUM            an issue's title, body and comments as markdown
#   tn-issue comment NUM FILE    comment on an open health issue (Claude's review)
#   tn-issue label NUM NAME      add a label (e.g. overnight) to an open health issue
#
# One issue per fingerprint, found again through the hidden <!-- fp:... -->
# marker in its body. Issues go to the overnight agents' queue repo with label
# akmon-health and a `repo: xin/Technonomicon` line, so Claude's review can add
# `overnight` to the ones a config change would fix. At most MAX_OPEN are open.
# Every action is appended to $STATE/events.tsv for the daily digest. Forgejo
# down or no token: logged, exit 0 (the mail paths still work).

API=${TN_ISSUE_API:-http://127.0.0.1:3000/api/v1}
REPO=${TN_ISSUE_REPO:-xin/agent-tasks}
WEB=${TN_ISSUE_WEB:-https://git.ironshark.org}
LABEL=akmon-health
STATE=${TN_ISSUE_STATE:-/var/lib/tn-alerts}
TOKEN_FILE=${TN_ISSUE_TOKEN:-/srv/forgejo/akmon-health-token}
MAX_OPEN=15
HOST=$(uname -n)
TOKEN=

mkdir -p "$STATE/fp"

# kind fp number title
event() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$1" "$2" "$3" "$4" >> "$STATE/events.tsv"; }
fpfile() { echo "$STATE/fp/$(printf '%s' "$1" | md5sum | cut -c1-16)"; }

api() { # METHOD PATH [JSON]
  local args=(-sf -m 20 -X "$1" -H "Authorization: token $TOKEN" -H "Content-Type: application/json")
  [ $# -ge 3 ] && args+=(--data "$3")
  curl "${args[@]}" "$API$2"
}

ready() {
  [ -r "$TOKEN_FILE" ] || return 1
  TOKEN=$(cat "$TOKEN_FILE")
  curl -sf -m 5 "$API/version" >/dev/null
}

label_id() {
  local id
  id=$(api GET "/repos/$REPO/labels?limit=100" | jq -r --arg n "$LABEL" '.[] | select(.name == $n) | .id')
  if [ -z "$id" ]; then
    id=$(api POST "/repos/$REPO/labels" "$(jq -nc --arg n "$LABEL" \
           '{name: $n, color: "#bf616a", description: "Reported by the server itself (Tn-server-alerts)"}')" | jq -r .id)
  fi
  echo "$id"
}

open_issues() { api GET "/repos/$REPO/issues?state=open&type=issues&labels=$LABEL&limit=50"; }

# open issues as: number <TAB> fp <TAB> title
issue_table() {
  open_issues | jq -r '.[] | [.number, (((.body // "") | capture("<!-- fp:(?<fp>[^ ]+) -->") | .fp) // ""), .title] | @tsv'
}

comment() { # number text
  api POST "/repos/$REPO/issues/$1/comments" "$(jq -nc --arg b "$2" '{body: $b}')" >/dev/null
}

close_issue() { # number fp why
  comment "$1" "$3" && api PATCH "/repos/$REPO/issues/$1" '{"state":"closed"}' >/dev/null || return 0
  local f; f=$(fpfile "$2")
  rm -f "$f".*
  event close "$2" "$1" ""
}

fenced() { # file -> markdown code block (empty when no file)
  [ -n "${1:-}" ] && [ -s "$1" ] || return 0
  local fence='```'
  printf '%s\n%s\n%s\n' "$fence" "$(head -c 20000 "$1")" "$fence"
}

report() {
  local fp=$1 sev=$2 title=$3 body=${4:-} f num nopen text
  f=$(fpfile "$fp")
  rm -f "$f.resolved"
  date +%s > "$f.seen"
  if ! ready; then event offline "$fp" - "$title"; return 0; fi

  num=$(issue_table | awk -F'\t' -v fp="$fp" '$2 == fp { print $1; exit }') || num=""
  if [ -n "$num" ]; then
    if [ -z "$(find "$f.commented" -mmin -360 2>/dev/null)" ]; then
      text="Still happening ($(date '+%a %d %b %H:%M %Z'))."$'\n\n'"$(fenced "$body")"
      comment "$num" "$text" && touch "$f.commented"
      event recur "$fp" "$num" "$title"
    fi
    return 0
  fi

  nopen=$(open_issues | jq length) || nopen=0
  if [ "${nopen:-0}" -ge "$MAX_OPEN" ]; then event capped "$fp" - "$title"; return 0; fi

  text=$(printf 'Reported by %s (Tn-server-alerts), severity **%s**, %s.\n\nrepo: xin/Technonomicon\n\n%s\n\n<!-- fp:%s -->\n' \
           "$HOST" "$sev" "$(date '+%a %d %b %H:%M %Z')" "$(fenced "$body")" "$fp")
  num=$(api POST "/repos/$REPO/issues" "$(jq -nc --arg t "[$HOST] $title" --arg b "$text" \
          --argjson l "$(label_id)" '{title: $t, body: $b, labels: [$l]}')" | jq -r .number)
  touch "$f.commented"
  event open "$fp" "$num" "$title"
  echo "$WEB/$REPO/issues/$num"
}

resolve() {
  local f; f=$(fpfile "$1")
  [ -e "$f.resolved" ] && return 0
  date +%s > "$f.resolved"
  event resolve "$1" - ""
}

sweep() {
  ready || return 0
  local now num fp title f seen since
  now=$(date +%s)
  while IFS=$'\t' read -r num fp title; do
    [ -n "$fp" ] || continue
    f=$(fpfile "$fp")
    case $fp in
      unit:*)
        systemctl is-failed --quiet "${fp#unit:}" || resolve "$fp" ;;
      burst:*|err:*)
        seen=$(cat "$f.seen" 2>/dev/null || echo 0)
        if [ $((now - seen)) -ge 172800 ]; then
          close_issue "$num" "$fp" "Not seen for 48 h; closing. It comes back as a new issue if it recurs."
          continue
        fi ;;
    esac
    if [ -e "$f.resolved" ]; then
      since=$(cat "$f.resolved")
      if [ $((now - since)) -ge 86400 ]; then
        close_issue "$num" "$fp" "Resolved: fine for 24 h; closing. It comes back as a new issue if it recurs."
      fi
    fi
  done < <(issue_table)
}

# only ever touch issues this tool opened (open, labelled akmon-health)
is_health_issue() { issue_table | awk -F'\t' -v n="$1" '$1 == n { f = 1 } END { exit !f }'; }

add_comment() { # num file
  ready || return 0
  is_health_issue "$1" || { echo "#$1 is not an open health issue" >&2; return 1; }
  comment "$1" "$(head -c 20000 "$2")"
  event comment - "$1" ""
}

add_label() { # num name
  ready || return 0
  is_health_issue "$1" || { echo "#$1 is not an open health issue" >&2; return 1; }
  local id
  id=$(api GET "/repos/$REPO/labels?limit=100" | jq -r --arg n "$2" '.[] | select(.name == $n) | .id')
  [ -n "$id" ] || { echo "no label $2 in $REPO" >&2; return 1; }
  api POST "/repos/$REPO/issues/$1/labels" "{\"labels\":[$id]}" >/dev/null
  event label - "$1" "$2"
}

show_issue() { # num
  ready || return 0
  api GET "/repos/$REPO/issues/$1" | jq -r '"# #\(.number) \(.title)\n\n\(.body)"'
  api GET "/repos/$REPO/issues/$1/comments" | jq -r '.[] | "\n---\n\(.user.login), \(.created_at):\n\n\(.body)"'
}

case "${1:-}" in
  report)  shift; report "$@" ;;
  resolve) shift; resolve "$1" ;;
  sweep)   sweep ;;
  list)    ready && issue_table ;;
  show)    show_issue "$2" ;;
  comment) add_comment "$2" "$3" ;;
  label)   add_label "$2" "$3" ;;
  *)       echo "usage: tn-issue report FP SEVERITY TITLE [BODY-FILE] | resolve FP | sweep | list | comment NUM FILE | label NUM NAME" >&2; exit 2 ;;
esac
