# lagent -- hand work to the local models on Akmon. Used by Claude when it
# supervises overnight runs (agents/overnight.sh), and usable by hand.
#
#   lagent ask  [-s SYSTEM] [-n MAX_TOKENS] PROMPT...   answer from the local chat model;
#                                                       piped stdin is appended as context
#   lagent code DIR INSTRUCTION [FILE...]               headless aider edit inside git repo DIR
#                                                       (never commits); prints the diffstat
#   lagent status                                       is the chat model up / night mode on?
#
# Endpoint: $LAGENT_URL (default http://127.0.0.1:8011, the on-demand chat
# server; the first request after an idle spell waits for it to load).

URL=${LAGENT_URL:-http://127.0.0.1:8011}

usage() {
  cat >&2 <<'EOF'
usage: lagent ask  [-s SYSTEM] [-n MAX_TOKENS] PROMPT...   (stdin = extra context)
       lagent code DIR INSTRUCTION [FILE...]               (aider edit, never commits)
       lagent status
EOF
  exit 2
}

ask() {
  local system="You are a careful senior software engineer. Be concise and concrete." max=2048
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

status() {
  if curl -sf --max-time 5 "$URL/health" >/dev/null; then
    echo "chat model: up ($URL)"
  else
    echo "chat model: not answering yet (it starts on first request)"
  fi
  if systemctl is-active --quiet llama-cpp.service; then
    echo "completion server: running (day mode -- chat shares the GPU)"
  else
    echo "completion server: stopped (night mode -- chat has the whole GPU)"
  fi
}

cmd=${1:-}; shift || true
case $cmd in
  ask)    ask "$@" ;;
  code)   code "$@" ;;
  status) status ;;
  *)      usage ;;
esac
