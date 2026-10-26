# lagent -- hand work to the local models on Akmon. Used by Claude when it
# supervises overnight runs (agents/overnight.sh), and usable by hand.
#
#   lagent ask  [-s SYSTEM] [-n MAX_TOKENS] PROMPT...   answer from the local chat model;
#                                                       piped stdin is appended as context
#   lagent code DIR INSTRUCTION [FILE...]               headless aider edit inside git repo DIR
#                                                       (never commits); prints the diffstat
#   lagent agent DIR TASK...                            headless Claude Code on the local model
#                                                       (claude-local) inside git repo DIR: reads,
#                                                       searches and edits across files over many
#                                                       steps; never commits. Prints its final
#                                                       answer, then what changed
#   lagent read SOURCE [QUESTION...]                    read a file or URL (PDF, HTML, DOCX, EPUB,
#                                                       text) with the local model: a summary, or
#                                                       what answers QUESTION; long documents are
#                                                       read in parts and the notes combined
#   lagent search [-n N] QUERY...                       top N results (default 10) from SearXNG
#                                                       (search.ironshark.org): title, url, snippet
#   lagent status                                       is the chat model up / night mode on?
#
# Endpoint: $LAGENT_URL (default http://127.0.0.1:8011, Strata on Akmon,
# woken on demand: the first request after an idle spell waits a minute or
# two for it to load).

URL=${LAGENT_URL:-http://127.0.0.1:8011}

usage() {
  cat >&2 <<'EOF'
usage: lagent ask  [-s SYSTEM] [-n MAX_TOKENS] PROMPT...   (stdin = extra context)
       lagent code DIR INSTRUCTION [FILE...]               (aider edit, never commits)
       lagent agent DIR TASK...                            (local Claude Code, never commits)
       lagent read SOURCE [QUESTION...]                    (file or URL; summary or answer)
       lagent search [-n N] QUERY...                       (SearXNG results)
       lagent status
EOF
  exit 2
}

ask() {
  # OPTIND is global and read_doc calls ask repeatedly: start getopts afresh
  local system="You are a careful senior software engineer. Be concise and concrete." max=2048 o OPTIND=1
  while getopts "s:n:" o; do
    case $o in s) system=$OPTARG ;; n) max=$OPTARG ;; *) usage ;; esac
  done
  shift $((OPTIND - 1))
  [ $# -gt 0 ] || usage
  local prompt="$*"
  if [ ! -t 0 ]; then
    prompt="$prompt"$'\n\n--- context ---\n'"$(cat)"
  fi
  jq -n --arg s "$system" --arg p "$prompt" --argjson m "$max" \
     '{model:"chat", max_tokens:$m, temperature:0.3,
       messages:[{role:"system",content:$s},{role:"user",content:$p}]}' \
  | curl -sf --max-time 1800 "$URL/v1/chat/completions" \
      -H 'Content-Type: application/json' -d @- \
  | jq -r '.choices[0].message.content'
}

code() {
  [ $# -ge 2 ] || usage
  local dir=$1 instr=$2; shift 2
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "lagent code: $dir is not a git repository" >&2; exit 1; }
  # aider reads ~/.aider.conf.yml (local chat model, no auto-commits); the
  # flags here make it non-interactive and quiet
  ( cd "$dir" && aider --yes-always --no-pretty --no-stream --no-auto-commits \
      --no-dirty-commits --no-gitignore --no-check-update \
      --message "$instr" "$@" ) >&2
  git -C "$dir" diff --stat
}

# Claude Code's own tools, on Strata. Edits are allowed inside DIR; shell
# commands only from this list (anything else is refused, as nobody is
# there to approve it). LAGENT_AGENT_TOOLS adds more, space separated, e.g.
# 'Bash(cargo test:*)'.
agent() {
  [ $# -ge 2 ] || usage
  local dir=$1; shift
  local task="$*"
  git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "lagent agent: $dir is not a git repository" >&2; exit 1; }
  local -a tools=(Read Edit Write Glob Grep
    'Bash(git diff:*)' 'Bash(git status:*)' 'Bash(git log:*)' 'Bash(git show:*)'
    'Bash(ls:*)' 'Bash(nix build:*)' 'Bash(nix flake check:*)' 'Bash(nix eval:*)')
  # shellcheck disable=SC2206  # word splitting is the point
  [ -n "${LAGENT_AGENT_TOOLS:-}" ] && tools+=(${LAGENT_AGENT_TOOLS})
  ( cd "$dir" && claude-local -p "$task" \
      --permission-mode acceptEdits \
      --allowedTools "${tools[@]}" \
      --disallowedTools 'Bash(git commit:*)' 'Bash(git push:*)' WebFetch WebSearch \
      --max-turns "${LAGENT_AGENT_TURNS:-60}" ) \
    || echo "lagent agent: claude-local stopped with an error (see above)" >&2
  echo
  echo "--- changes ---"
  git -C "$dir" status --short
  git -C "$dir" diff --stat
}

# Strata has a 128k-token context: documents go through it in parts of
# ~240k characters (~60k tokens; split at blank lines where it can), one
# set of notes per part, then a pass that combines the notes.
CHUNK_CHARS=240000

read_doc() {
  [ $# -ge 1 ] || usage
  local src=$1; shift
  local question="$*" tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  if [[ $src =~ ^https?:// ]]; then
    curl -sfL --max-time 120 -o "$tmp/doc" "$src" \
      || { echo "lagent read: could not fetch $src" >&2; exit 1; }
  else
    [ -r "$src" ] || { echo "lagent read: cannot read $src" >&2; exit 1; }
    cp -- "$src" "$tmp/doc"
  fi

  case $(file -b --mime-type "$tmp/doc") in
    application/pdf)
      # page breaks become [page N] markers so notes can cite pages
      pdftotext -layout "$tmp/doc" - | awk '
        BEGIN { p = 1; print "[page 1]" }
        { n = split($0, a, "\f"); for (i = 1; i <= n; i++) { if (i > 1) print "[page " ++p "]"; print a[i] } }
      ' > "$tmp/text" ;;
    text/html|application/xhtml+xml)
      pandoc -f html -t plain --wrap=none "$tmp/doc" -o "$tmp/text" ;;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document)
      pandoc -f docx -t plain --wrap=none "$tmp/doc" -o "$tmp/text" ;;
    application/epub+zip)
      pandoc -f epub -t plain --wrap=none "$tmp/doc" -o "$tmp/text" ;;
    *) cp "$tmp/doc" "$tmp/text" ;;
  esac
  [ -s "$tmp/text" ] || { echo "lagent read: no text could be extracted from $src" >&2; exit 1; }

  mkdir "$tmp/parts"
  awk -v max="$CHUNK_CHARS" -v dir="$tmp/parts" '
    BEGIN { n = 1; size = 0 }
    {
      len = length($0) + 1
      if (size > 0 && (size + len > max || ($0 == "" && size > max * 0.75))) { n++; size = 0 }
      print > (dir "/" sprintf("%04d", n)); size += len
    }
  ' "$tmp/text"
  local parts=("$tmp"/parts/*) total
  total=${#parts[@]}

  local task
  if [ -n "$question" ]; then
    task="From this document, answer: $question
Quote key definitions, figures and numbers exactly, and cite [page N] or section names where present."
  else
    task="Summarize this document: its purpose, key claims, methods, results, numbers and definitions. Keep section names and cite [page N] where present."
  fi

  if [ "$total" -eq 1 ]; then
    ask -n 3000 "$task" < "${parts[0]}"
    return
  fi

  local i=0 part
  for part in "${parts[@]}"; do
    i=$((i + 1))
    echo "lagent read: part $i/$total" >&2
    printf '## part %d of %d\n' "$i" "$total" >> "$tmp/notes"
    if [ -n "$question" ]; then
      ask -n 1500 "This is part $i of $total of a document. Extract everything in it that helps answer: $question
Quote key figures and definitions exactly and cite [page N] or sections. If nothing in this part is relevant, say only: nothing relevant." < "$part" >> "$tmp/notes"
    else
      ask -n 1500 "This is part $i of $total of a document. Note its key claims, methods, results, numbers and definitions, with section names and [page N]." < "$part" >> "$tmp/notes"
    fi
    printf '\n\n' >> "$tmp/notes"
  done
  ask -n 3000 "These are notes taken from the $total parts of one document ($src), in order. $task
Work only from the notes; say what they do not cover." < "$tmp/notes"
}

search() {
  local n=10 o OPTIND=1
  while getopts "n:" o; do
    case $o in n) n=$OPTARG ;; *) usage ;; esac
  done
  shift $((OPTIND - 1))
  [ $# -gt 0 ] || usage
  curl -sf --max-time 30 -G "${LAGENT_SEARCH_URL:-https://search.ironshark.org}/search" \
      --data-urlencode "q=$*" --data-urlencode "format=json" \
    | jq -r --argjson n "$n" '
        .results[:$n][]
        | "\(.title)\n  \(.url)\n  \((.content // "") | gsub("\\s+"; " ") | .[0:300])\n"'
}

status() {
  # from the units: a request would wake Strata
  if systemctl is-active --quiet podman-strata.service; then
    echo "Strata: loaded ($URL)"
  elif systemctl is-active --quiet strata.socket; then
    echo "Strata: asleep; the next request wakes it (a minute or two)"
  else
    echo "Strata: off (gpu-lend?)"
  fi
  if systemctl is-active --quiet llama-fim-server.service; then
    echo "completion server: loaded"
  elif systemctl is-active --quiet llama-fim.socket; then
    echo "completion server: asleep until the next completion request"
  elif systemctl is-active --quiet podman-strata.service; then
    echo "completion server: off while Strata has the GPU (back when Strata sleeps)"
  else
    echo "completion server: off (night mode or gpu-lend)"
  fi
}

cmd=${1:-}; shift || true
case $cmd in
  ask)    ask "$@" ;;
  code)   code "$@" ;;
  agent)  agent "$@" ;;
  read)   read_doc "$@" ;;
  search) search "$@" ;;
  status) status ;;
  *)      usage ;;
esac
