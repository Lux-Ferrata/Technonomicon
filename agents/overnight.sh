# overnight -- work through the agent task queue on Akmon, Claude supervising
# the local models (lagent). Runs as xin from a user timer each night, or by
# hand: `systemctl --user start overnight` (Kvasir: `overnight-now`).
#
# Queue: open issues labeled `overnight` in Forgejo repo $QUEUE. The issue
# body may contain lines like
#     project: esn-precision-study      (a git repo in ~/Projects)
#     repo: xin/Technonomicon           (a Forgejo repo; work lands as a PR)
# Neither -> a research/writing task; its notes are committed to $QUEUE
# under research/.
#
# Containment: every task gets a throwaway clone under $WORKROOT. Claude runs
# without any push credential, forge token or ssh agent (its unit can't see
# /run/secrets at all); this script does the pushing, PRs and issue comments
# afterwards. Nothing is ever merged.
set -uo pipefail

API=http://127.0.0.1:3000/api/v1
WEB=https://git.ironshark.org
QUEUE=${QUEUE:-xin/agent-tasks}
TOKEN=$(cat /run/secrets/forgejo-agent-token)
MAIL_TO="xin@ironshark.org"
MAIL_FROM="Akmon overnight agents <homelab@ironshark.org>"
STAMP=$(date +%F-%H%M)
WORKROOT=/srv/xin/agent-work/$STAMP
TASK_MINUTES=${TASK_MINUTES:-90}
mkdir -p "$WORKROOT"
SUMMARY=$WORKROOT/summary.txt
: > "$SUMMARY"
exec > >(tee -a "$WORKROOT/log") 2>&1
REPORTS=$WORKROOT/reports.md
: > "$REPORTS"
TASKS=0

# Every run ends with an email -- including one that crashes -- so the
# owner never has to keep a session open. The body carries each task's full
# report; an empty queue only mails for manual (daytime) runs.
finish() {
  local rc=$?
  if [ "$TASKS" -eq 0 ] && [ $rc -eq 0 ] && [ "$(date -d "@$START" +%H)" -lt 6 ]; then
    exit 0
  fi
  local done_n other_n status subject
  done_n=$(grep -c ': done' "$SUMMARY" || true)
  other_n=$(grep -vc ': done' "$SUMMARY" || true)
  if [ $rc -ne 0 ]; then status="FAILED (exit $rc)"
  elif [ "$TASKS" -eq 0 ]; then status="nothing queued"
  else status="$done_n done, $other_n other"; fi
  subject="[Akmon] overnight agents: $status"
  {
    echo "To: $MAIL_TO"; echo "From: $MAIL_FROM"; echo "Subject: $subject"
    echo "Content-Type: text/plain; charset=utf-8"; echo
    echo "Overnight agent run $STAMP -- $status"
    echo "Started $(date -d "@$START" '+%a %H:%M'), finished $(date '+%H:%M')."
    echo
    if [ -s "$SUMMARY" ]; then cat "$SUMMARY"; echo; fi
    if [ $rc -ne 0 ]; then
      echo "The run stopped early. Last 60 log lines:"; echo
      tail -n 60 "$WORKROOT/log"; echo
    fi
    if [ -s "$REPORTS" ]; then
      echo "======================================================================"
      cat "$REPORTS"
    fi
    echo
    echo "Queue: $WEB/$QUEUE/issues"
    echo "Logs and work dirs: $WORKROOT on Akmon (kept 14 days)."
    echo "To follow up, tell Claude: \"look at overnight run $STAMP\"."
  } | /run/wrappers/bin/sendmail -t || echo "mail failed"
  exit $rc
}
START=$(date +%s)
trap finish EXIT

# Stop starting new tasks at the deadline: before the 03:00 weekly job on
# Wednesdays, before the 05:45 day-mode switch otherwise; a daytime manual
# run gets $MAX_HOURS (default 4).
now=$(date +%s)
if [ "$(date +%H)" -lt 6 ]; then
  if [ "$(date +%u)" = 3 ]; then end="02:40"; else end="05:30"; fi
  DEADLINE=$(date -d "today $end" +%s)
else
  DEADLINE=$(( now + ${MAX_HOURS:-4} * 3600 ))
fi

api() { # METHOD PATH [JSON]
  curl -sf -X "$1" -H "Authorization: token $TOKEN" -H 'Content-Type: application/json' \
       "$API$2" ${3:+-d "$3"}
}
label_id() { api GET "/repos/$QUEUE/labels?limit=100" | jq -r --arg n "$1" '.[] | select(.name==$n) | .id'; }
add_label()    { api POST   "/repos/$QUEUE/issues/$1/labels" "{\"labels\":[$(label_id "$2")]}" >/dev/null; }
remove_label() { api DELETE "/repos/$QUEUE/issues/$1/labels/$(label_id "$2")" >/dev/null; }
comment()      { jq -n --rawfile b "$2" '{body:$b}' | api POST "/repos/$QUEUE/issues/$1/comments" "$(cat)" >/dev/null; }
git_auth()     { git -c "http.extraHeader=Authorization: token $TOKEN" "$@"; }

export CLAUDE_CODE_OAUTH_TOKEN
CLAUDE_CODE_OAUTH_TOKEN=$(cat /run/secrets/claude-oauth-token)
# no ssh agent / forwarded keys for anything Claude starts
unset SSH_AUTH_SOCK

issues=$(api GET "/repos/$QUEUE/issues?state=open&type=issues&labels=overnight&limit=50") \
  || { echo "cannot read the queue"; exit 1; }
count=$(jq length <<<"$issues")
TASKS=$count
echo "overnight $STAMP: $count task(s), deadline $(date -d @"$DEADLINE" +%H:%M)"
[ "$count" -gt 0 ] || exit 0

# oldest first
for row in $(jq -r 'sort_by(.number) | .[] | @base64' <<<"$issues"); do
  issue() { base64 -d <<<"$row" | jq -r "$1"; }
  n=$(issue .number); title=$(issue .title); body=$(issue '.body // ""')
  left=$(( DEADLINE - $(date +%s) ))
  if [ $left -lt 900 ]; then
    echo "- #$n $title: not started (out of time)" >> "$SUMMARY"; continue
  fi
  budget=$(( left < TASK_MINUTES * 60 ? left : TASK_MINUTES * 60 ))

  project=$(grep -oP '^\s*project:\s*\K\S+' <<<"$body" | head -1 || true)
  repo=$(grep -oP '^\s*repo:\s*\K\S+' <<<"$body" | head -1 || true)
  slug=$(tr -cs '[:alnum:]' '-' <<<"$title" | tr '[:upper:]' '[:lower:]' | cut -c1-40 | sed 's/-$//')
  branch="overnight/$n-$slug"
  dir=$WORKROOT/$n; out=$WORKROOT/$n.out; mkdir -p "$out"
  echo; echo "==== #$n $title (project=${project:-} repo=${repo:-}) budget $((budget/60))m"
  add_label "$n" in-progress

  kind=research; base=""
  if [ -n "$repo" ]; then
    kind=code
    git_auth clone -q "http://127.0.0.1:3000/$repo.git" "$dir" || { kind=failed; }
    base=$(api GET "/repos/$repo" | jq -r .default_branch)
    # Technonomicon: main is written only by the weekly bot
    [ "$repo" = xin/Technonomicon ] && base=working
    [ "$kind" = code ] && git -C "$dir" checkout -q "$base"
  elif [ -n "$project" ]; then
    kind=code
    git clone -q "$HOME/Projects/$project" "$dir" || kind=failed
    base=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
  else
    mkdir -p "$dir"
  fi

  if [ "$kind" != failed ] && [ "$kind" = code ]; then
    git -C "$dir" checkout -q -b "$branch"
    git -C "$dir" config user.name  "overnight agent (Claude + local models)"
    git -C "$dir" config user.email "homelab@ironshark.org"
    git -C "$dir" config commit.gpgsign false
  fi

  if [ "$kind" != failed ]; then
    comments=$(api GET "/repos/$QUEUE/issues/$n/comments" | jq -r '.[] | "--- \(.user.login):\n\(.body)\n"')
    prompt="You are running unattended overnight on Akmon (a headless NixOS server with an RTX 5080) as the SUPERVISOR of local language models. Task #$n from the queue, verbatim:

TITLE: $title
$body
${comments:+
Earlier comments on the task:
$comments}

How to work:
- Your working directory is $dir ($([ "$kind" = code ] && echo "a fresh clone on branch $branch, based on $base" || echo "an empty scratch directory")). Never touch anything outside it and $out; never push, and never try to obtain credentials -- the calling script publishes your results.
- Delegate the bulk work to the local models, then review it yourself: \`lagent ask 'question' < file\` (summaries, drafts, explanations; stdin is context), \`lagent read FILE-OR-URL ['question']\` (reads a whole PDF/web page/document locally, in parts, and returns a summary or the answer with page refs: use it instead of reading long documents yourself), \`lagent search 'query'\` (web results from the local SearXNG) and \`lagent code DIR 'instruction' FILE...\` (aider edits files, never commits; review the diff with git diff, keep or discard). They are much weaker than you: give them small, concrete, well-scoped pieces; you own correctness. Do it yourself when delegating would be slower or riskier.
- $([ "$kind" = code ] && echo "Commit finished, reviewed work on $branch in small commits with clear messages. Build/test it (respect the repo's CLAUDE.md, flake devShell, test commands) before committing. Leave unfinished or doubtful work out of the commits and describe it instead." || echo "This is a research/writing task: put the result in $out/notes.md as a well-structured markdown document with sources (URLs) for factual claims. You may use web search/fetch.")
- You have about $((budget/60)) minutes. Stop in time to write the report.
- Finally write $out/REPORT.md for the owner, who reads it in the morning: what you did, what the local models did, what you verified and how, what is left or uncertain. Be honest about failures; a clear 'could not do X because Y' beats a weak result."

    # Claude runs in a transient unit of its own: same user, network and
    # tools, but the credentials on disk (forge and Claude tokens, signing
    # and Syncthing keys, the Google calendar token) don't exist for it, so
    # nothing it reads on the web or in an issue can get them out. The
    # budget is RuntimeMaxSec: systemd stops it when time is up.
    systemd-run --user --pipe --wait --collect --quiet \
        -p PrivateUsers=yes \
        -p InaccessiblePaths=/run/secrets -p InaccessiblePaths=-/run/secrets.d \
        -p InaccessiblePaths=-/srv/xin/.syncthing -p InaccessiblePaths=-/srv/xin/.calendar-push \
        -p WorkingDirectory="$dir" -p RuntimeMaxSec="$budget" \
        -E PATH -E CLAUDE_CODE_OAUTH_TOKEN \
        claude -p "$prompt" --output-format text \
          --add-dir "$out" \
          --allowedTools "Read,Edit,Write,Glob,Grep,WebSearch,WebFetch,Bash" \
        > "$out/claude.txt" 2>&1 || echo "(claude exited with $?)" >> "$out/claude.txt"
  fi

  # ---- publish ----------------------------------------------------------
  report=$out/REPORT.md
  if [ ! -s "$report" ]; then
    { echo "No REPORT.md was written$([ "$kind" = failed ] && echo " (the clone failed)"). Last output:"
      echo '```'; tail -n 40 "$out/claude.txt" 2>/dev/null; echo '```'; } > "$report"
  fi
  link=""
  if [ "$kind" = code ] && [ -n "$(git -C "$dir" log --oneline "$base..$branch" 2>/dev/null)" ]; then
    if [ -n "$repo" ]; then
      git_auth -C "$dir" push -q origin "$branch"
      pr=$(jq -n --arg t "overnight #$n: $title" --arg h "$branch" --arg b "$base" \
              --rawfile body "$report" '{title:$t, head:$h, base:$b, body:$body}' \
           | api POST "/repos/$repo/pulls" "$(cat)" | jq -r .html_url)
      link="PR: $pr"
    else
      git -C "$dir" push -q origin "$branch"
      link="branch \`$branch\` in ~/Projects/$project (synced to Kvasir)"
    fi
  elif [ "$kind" = research ] && [ -s "$out/notes.md" ]; then
    path="research/$n-$slug.md"
    jq -n --arg m "overnight #$n: $title" --arg c "$(base64 -w0 "$out/notes.md")" \
       '{message:$m, content:$c}' | api POST "/repos/$QUEUE/contents/$path" "$(cat)" >/dev/null \
      && link="notes: $WEB/$QUEUE/src/branch/main/$path"
  fi
  { [ -n "$link" ] && printf '**Result:** %s\n\n' "$link"; cat "$report"; } > "$out/comment.md"
  comment "$n" "$out/comment.md"
  { echo "## #$n $title"; echo "$WEB/$QUEUE/issues/$n"; echo; cat "$out/comment.md"; echo; } >> "$REPORTS"
  remove_label "$n" in-progress
  remove_label "$n" overnight
  if [ -n "$link" ]; then
    add_label "$n" "done"
    api PATCH "/repos/$QUEUE/issues/$n" '{"state":"closed"}' >/dev/null
    echo "- #$n $title: done -- $link" >> "$SUMMARY"
  else
    add_label "$n" needs-attention
    echo "- #$n $title: needs attention (no result; see the issue)" >> "$SUMMARY"
  fi
done
