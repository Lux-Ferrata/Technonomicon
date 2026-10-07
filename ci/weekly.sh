#!/usr/bin/env bash
# Weekly job (Wednesdays 03:00 America/Phoenix, see .forgejo/workflows/weekly.yml)
#
#   1. upgrade:  nix flake update on top of `working`, build every host,
#                let Claude fix breakage (max 3 rounds), push the result to `working`
#   2. curate:   regroup everything on `working` since the last curated/* tag into
#                feature commits on top of `main`; main's tree must end up
#                byte-identical to `working`
#   3. publish:  push main, tag curated/<date>, keep build results as GC roots so
#                Akmon's cache can serve them, email a summary
#
# Anything going wrong -> main is not touched and a failure email goes out.
# MODE=dry-run does all the work but pushes/tags nothing (email says so).
set -eEuo pipefail   # -E: the ERR trap also fires inside functions

HOSTS=(Akmon Kvasir)
MAIL_TO="xin@ironshark.org"
MAIL_FROM="Technonomicon bot <homelab@ironshark.org>"
SENDMAIL=/run/wrappers/bin/sendmail
TODAY=$(date +%F)
MODE=${MODE:-live}
WORK=$(mktemp -d)
ROOTS="$HOME/gcroots"
STAGE=startup

mkdir -p "$ROOTS"
: > "$WORK/notes"
exec > >(tee -a "$WORK/log") 2>&1

log()   { STAGE=$*; printf '\n==== %s ====\n' "$*"; }
note()  { printf -- '- %s\n' "$*" >> "$WORK/notes"; }
push()  { if [ "$MODE" = live ]; then git push "$@"; else echo "[dry-run] git push $*"; fi; }

send_mail() { # subject body-file [monospace-file]
  # multipart: plain text, plus HTML so the optional table (column-aligned
  # with spaces) shows in a monospace block instead of Gmail's proportional font
  local b="tn-$$-$RANDOM"
  esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$1"; }
  {
    echo "To: $MAIL_TO"
    echo "From: $MAIL_FROM"
    echo "Subject: $1"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/alternative; boundary=\"$b\""
    echo
    echo "--$b"
    echo "Content-Type: text/plain; charset=utf-8"
    echo
    cat "$2"
    [ -n "${3:-}" ] && { echo; echo "----"; cat "$3"; }
    echo
    echo "--$b"
    echo "Content-Type: text/html; charset=utf-8"
    echo
    echo '<div style="font-family:sans-serif;font-size:14px;line-height:1.45;white-space:pre-wrap;max-width:46em">'
    esc "$2"
    echo '</div>'
    if [ -n "${3:-}" ]; then
      echo '<pre style="font-family:ui-monospace,Menlo,Consolas,monospace;font-size:13px;line-height:1.35;background:#f4f4f4;color:#222;padding:10px 12px;border-radius:6px;overflow-x:auto">'
      esc "$3"
      echo '</pre>'
    fi
    echo "--$b--"
  } | "$SENDMAIL" -t
}

on_error() {
  local rc=$?
  {
    echo "The weekly job failed during: $STAGE (exit $rc, mode $MODE)."
    echo "main was NOT changed."
    echo
    echo "Notes so far:"
    cat "$WORK/notes"
    echo
    echo "Last 100 log lines:"
    tail -n 100 "$WORK/log"
  } > "$WORK/failmail"
  send_mail "[Technonomicon] weekly job FAILED ($TODAY)" "$WORK/failmail" || true
  exit "$rc"
}
trap on_error ERR

export CLAUDE_CODE_OAUTH_TOKEN
CLAUDE_CODE_OAUTH_TOKEN=$(cat /run/secrets/claude-oauth-token)

# headless Claude; only the tools each step needs, nothing that can push
claude_do() { # prompt allowed-tools
  claude -p "$1" --output-format text \
    --add-dir "$WORK" --allowedTools "$2"
}

build_all() { # -> 0 if every host builds; logs in $WORK/build-<host>.log
  local rc=0 h
  for h in "${HOSTS[@]}"; do
    # no eval cache: a cached evaluation prints no warnings (see eval_warnings)
    if nix build --keep-going -L --option eval-cache false --out-link "$WORK/result-$h" \
         ".#nixosConfigurations.$h.config.system.build.toplevel" \
         > "$WORK/build-$h.log" 2>&1; then
      echo "build $h: ok"
    else
      echo "build $h: FAILED (tail below)"; tail -n 30 "$WORK/build-$h.log"; rc=1
    fi
  done
  return $rc
}

# ---------------------------------------------------------------------------
log "setup"
git config user.name  "Technonomicon bot"
git config user.email "homelab@ironshark.org"
git config commit.gpgsign false
git config tag.gpgsign false
git fetch --quiet --tags origin \
  '+refs/heads/working:refs/remotes/origin/working' \
  '+refs/heads/main:refs/remotes/origin/main'
prev_tag=$(git tag -l 'curated/*' --sort=-creatordate | head -n 1)
[ -n "$prev_tag" ] || { echo "no curated/* tag to start from"; false; }
git checkout -q -B weekly origin/working
start=$(git rev-parse HEAD)
echo "mode=$MODE prev=$prev_tag working=$(git rev-parse --short HEAD) main=$(git rev-parse --short origin/main)"

# ---------------------------------------------------------------------------
log "upgrade: nix flake update"
nix flake update 2>&1 | tee "$WORK/flake-update.txt"
upgraded=0
if git diff --quiet -- flake.lock; then
  note "flake update: every input was already current"
else
  rounds=0
  until build_all; do
    rounds=$((rounds + 1))
    if [ $rounds -gt 3 ]; then
      note "upgrade DROPPED: hosts still failed to build after 3 fix rounds (logs in the job output)"
      git reset -q --hard "$start"
      break
    fi
    log "upgrade: fix round $rounds"
    claude_do "You are fixing a weekly \`nix flake update\` of this NixOS flake repository (the current directory) that left some hosts failing to build. Build logs: $WORK/build-*.log (hosts: ${HOSTS[*]}).

Rules from the repository owner:
- Find which package(s) broke. Prefer pinning the broken package to nixpkgs-stable (pkgs-stable is already passed to modules as a module argument). If moving to stable would change on-disk data formats the user relies on, pin it to the previous nixpkgs revision through a dedicated flake input instead (see the existing nixpkgs-zotero input for the pattern).
- Keep every change minimal and leave a short comment with today's date ($TODAY) and the reason.
- Follow CLAUDE.md. Never modify, weaken or route around the distraction-blocking configuration.
- Do not commit or push; the calling script does that.
- Verify with: nix build --no-link .#nixosConfigurations.<Host>.config.system.build.toplevel

When done, write a short plain-text summary (what broke, what you changed, why) to $WORK/fixes.txt, appending if it exists." \
      "Read,Edit,Write,Glob,Grep,Bash(nix build:*),Bash(nix eval:*),Bash(nix flake:*),Bash(nix log:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*)" \
      || note "Claude fix round $rounds exited with an error"
  done
  if ! git diff --quiet; then
    upgraded=1
    {
      echo "flake: weekly update ($TODAY)"
      echo
      if [ -s "$WORK/fixes.txt" ]; then echo "Fixes applied during the update:"; cat "$WORK/fixes.txt"; fi
    } > "$WORK/upgrade-msg"
    git add -A
    git commit -q -F "$WORK/upgrade-msg"
    note "flake update: committed $(git rev-parse --short HEAD)$([ -s "$WORK/fixes.txt" ] && echo ' (with fixes, see below)')"
  fi
fi

# whatever we ended up with must build (also covers "upgrade dropped")
if [ $upgraded -eq 0 ]; then
  log "build working as-is"
  build_all
fi

# ---------------------------------------------------------------------------
# evaluation warnings (deprecated options, renamed packages, ...). Only nix's
# own warning lines: -L build output is prefixed "<drv>> ", so compiler
# warnings never match.
eval_warnings() { # -> $WORK/warnings.txt, empty if none
  local h
  : > "$WORK/warnings.txt"
  for h in "${HOSTS[@]}"; do
    grep -E -A4 '^(evaluation warning|trace: warning):' "$WORK/build-$h.log" \
      | sed "s/^/[$h] /" >> "$WORK/warnings.txt" || true
  done
}
fixed_warnings=0
eval_warnings
if [ -s "$WORK/warnings.txt" ]; then
  log "warnings: fix"
  warn_start=$(git rev-parse HEAD)
  claude_do "Fix the Nix evaluation warnings this NixOS flake repository (the current directory) produces. They are listed in $WORK/warnings.txt (prefixed with the host); full build logs are $WORK/build-*.log (hosts: ${HOSTS[*]}).

Rules from the repository owner:
- Fix every warning caused by this repository's own configuration: renamed or deprecated options, renamed packages, deprecated functions, and so on. Use the replacement the warning names, and keep behaviour identical.
- Leave alone warnings that come from inside a flake input (nixpkgs internals, home-manager modules, etc.) and that this repo cannot fix without patching the input.
- Keep every change minimal. Follow CLAUDE.md. Never modify, weaken or route around the distraction-blocking configuration.
- Do not commit or push; the calling script does that.
- Verify with: nix build --no-link .#nixosConfigurations.<Host>.config.system.build.toplevel

When done, write a short plain-text summary to $WORK/warning-fixes.txt: which warnings you fixed (and how), and which you left and why." \
    "Read,Edit,Write,Glob,Grep,Bash(nix build:*),Bash(nix eval:*),Bash(nix log:*),Bash(git diff:*),Bash(git log:*),Bash(git show:*)" \
    || note "Claude warning-fix exited with an error"
  if ! git diff --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    if build_all; then
      { echo "eval: fix evaluation warnings ($TODAY)"; echo
        cat "$WORK/warning-fixes.txt" 2>/dev/null; } > "$WORK/warn-msg"
      git add -A
      git commit -q -F "$WORK/warn-msg"
      fixed_warnings=1
      note "evaluation warnings: fixes committed $(git rev-parse --short HEAD)"
    else
      note "evaluation warnings: fixes DROPPED, they broke the build"
      git reset -q --hard "$warn_start"
      git clean -fdq
      build_all
    fi
  fi
  eval_warnings
  if [ -s "$WORK/warnings.txt" ]; then
    note "evaluation warnings still present: $(grep -cE '\] (evaluation warning|trace: warning):' "$WORK/warnings.txt") (see warnings.txt / warning-fixes.txt)"
  else
    note "evaluation warnings: none left"
  fi
fi
new=$(git rev-parse HEAD)

if [ "$new" != "$start" ]; then
  log "push upgrade to working"
  # fast-forward only: if working moved during the run, stop rather than
  # race the human; the next run picks everything up
  push origin "$new:refs/heads/working"
fi

# ---------------------------------------------------------------------------
log "curate"
# --no-renames: a rename is just delete + add, so every path is handled on its own
git diff --no-renames --name-status origin/main "$new" > "$WORK/files.txt"
git log --reverse --format='%h %ad %s' --date=short "$prev_tag..$new" > "$WORK/commits.txt"
git diff --stat origin/main "$new" > "$WORK/diffstat.txt"

if [ ! -s "$WORK/files.txt" ]; then
  note "no changes since $prev_tag; main left as is"
  curated=0
else
  claude_do "Plan this week's curated history for this NixOS config repository.

main is at $(git rev-parse --short origin/main); the working branch is at $(git rev-parse --short "$new"). Everything that differs between them must be regrouped into a handful of feature commits on top of main.

Inputs: $WORK/commits.txt (the raw commits, many are auto-generated 'auto: update <file>' snapshots, ignore those messages), $WORK/files.txt (git name-status of every changed path), $WORK/diffstat.txt. Inspect the real changes with git diff origin/main $new -- <path>, git show, git log.

Write JSON to $WORK/plan.json, exactly this shape:
{\"groups\": [{\"title\": \"...\", \"body\": \"...\", \"files\": [\"path\", ...]}]}
- Every path from files.txt in exactly one group.
- Usually 2-8 groups, ordered so earlier groups make sense on their own.
- title: imperative, <= 72 chars, scope prefix like 'akmon:', 'kvasir:', 'shell:', 'flake:', 'ci:'.
- body: 1-6 plain lines, what changed and why, written for the owner reading the log later.
Only write plan.json; change nothing else." \
    "Read,Write,Glob,Grep,Bash(git diff:*),Bash(git log:*),Bash(git show:*)"

  log "curate: apply plan"
  git checkout -q -B curate origin/main
  take() { # path: make it match $new (add/modify or delete)
    if git cat-file -e "$new:$1" 2>/dev/null; then git checkout -q "$new" -- "$1"
    else git rm -q --ignore-unmatch -- "$1"; fi
  }
  n=$(jq '.groups | length' "$WORK/plan.json")
  for i in $(seq 0 $((n - 1))); do
    title=$(jq -r ".groups[$i].title" "$WORK/plan.json")
    body=$(jq -r ".groups[$i].body"  "$WORK/plan.json")
    while IFS= read -r f; do
      # only paths that really changed (exact match on the path column)
      if awk -F'\t' -v f="$f" '$2 == f {found=1} END {exit !found}' "$WORK/files.txt"; then
        take "$f"
      fi
    done < <(jq -r ".groups[$i].files[]" "$WORK/plan.json")
    if ! git diff --cached --quiet; then
      git commit -q -m "$title" -m "$body"
    fi
  done
  # anything the plan missed
  leftover=$(git diff --no-renames --name-only HEAD "$new")
  if [ -n "$leftover" ]; then
    while IFS= read -r f; do take "$f"; done <<< "$leftover"
    git commit -q -m "misc: remaining changes from the week" \
      -m "Paths the grouping did not cover:" -m "$leftover"
    note "grouping missed some paths; they went into a 'misc' commit"
  fi

  log "curate: verify"
  if [ "$(git rev-parse 'HEAD^{tree}')" != "$(git rev-parse "$new^{tree}")" ]; then
    echo "curated tree differs from working"; false
  fi
  echo "tree identical to working $(git rev-parse --short "$new")"
  git log --format='%h %s' origin/main..HEAD | tee "$WORK/curated.txt"
  curated=1
fi

# ---------------------------------------------------------------------------
log "publish"
if [ $curated -eq 1 ]; then
  push origin "HEAD:refs/heads/main"
fi
if [ "$MODE" = live ]; then
  git tag -f -a "curated/$TODAY" -m "Weekly cutoff $TODAY" "$new"   # -f: same-day rerun
  push -f origin "curated/$TODAY"
fi

# keep this week's systems alive in the store (Akmon's cache serves them to
# Kvasir) and diff against last week's for the email
: > "$WORK/closures.txt"
for h in "${HOSTS[@]}"; do
  if [ -e "$ROOTS/$h" ]; then
    { echo "== $h"; nix store diff-closures "$ROOTS/$h" "$WORK/result-$h" | head -n 60; echo; } >> "$WORK/closures.txt" || true
  else
    echo "== $h: no baseline yet (first live run records one); not a problem" >> "$WORK/closures.txt"
  fi
  if [ "$MODE" = live ]; then
    rm -f "$ROOTS/$h"
    nix build --out-link "$ROOTS/$h" "$(readlink -f "$WORK/result-$h")"
  fi
done

# Akmon's week in numbers (Tn-server-usage logs a sample every 5 min)
TN_USAGE=/run/current-system/sw/bin/tn-usage
if [ -x "$TN_USAGE" ]; then
  "$TN_USAGE" --week > "$WORK/usage.txt" 2>&1 || echo "(tn-usage --week failed)" >> "$WORK/usage.txt"
else
  echo "(no usage log on this host)" > "$WORK/usage.txt"
fi

# ---------------------------------------------------------------------------
log "email"
claude_do "Write this week's summary email body (plain text, no markdown headings, ~150-400 words) for the owner of this NixOS config repo. Save it to $WORK/summary.txt.

Material: $WORK/notes (facts from the run, include every problem), $WORK/curated.txt (new commits on main; may be missing if nothing changed), $WORK/plan.json, $WORK/flake-update.txt, $WORK/closures.txt (package version changes per host; may be empty), $WORK/fixes.txt (may be missing), $WORK/warnings.txt and $WORK/warning-fixes.txt (evaluation warnings left and fixed; may be missing), $WORK/usage.txt (Akmon's CPU/RAM/GPU/pool usage over the week).

Structure: one-line verdict; what changed this week grouped like the curated commits; package upgrades worth knowing about (skip noise); anything pinned or fixed and why; evaluation warnings fixed and any left over; a two-or-three-sentence paragraph on Akmon's usage this week (what it mostly did, anything unusual: sustained high load, pool growth, reboots, gaps, failed units; the full table is appended after your text, so don't repeat it); problems needing attention. End with exactly:
To update Kvasir:  cd ~/Projects/Technonomicon && git pull && deploy kvasir
Akmon:             updates itself from main at 06:00
$([ "$MODE" = live ] || echo "Start with a line saying this was a DRY RUN and nothing was pushed.")" \
  "Read,Write,Bash(git log:*),Bash(git show:*)" || true

if [ ! -s "$WORK/summary.txt" ]; then
  { echo "(Claude could not write the summary; raw notes follow)"; cat "$WORK/notes"
    echo; cat "$WORK/curated.txt" 2>/dev/null; } > "$WORK/summary.txt"
fi
subject="[Technonomicon] weekly $TODAY: $(wc -l < "$WORK/curated.txt" 2>/dev/null || echo 0) commits"
[ $upgraded -eq 1 ] && subject="$subject + flake update"
[ "$MODE" = live ] || subject="$subject (DRY RUN)"
send_mail "$subject" "$WORK/summary.txt" "$WORK/usage.txt"
echo "done"
