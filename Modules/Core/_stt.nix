# `stt`: speech to text through the Whisper server at 127.0.0.1:8020 --
# on Akmon its own GPU server, on Kvasir a proxy that prefers Akmon and
# falls back to a small local CPU model (Tn-dev-client).
{ writeShellApplication, curl, pipewire, coreutils, gnused, wl-clipboard }:
writeShellApplication {
  name = "stt";
  runtimeInputs = [ curl pipewire coreutils gnused wl-clipboard ];
  text = ''
    usage() {
      cat <<'EOF'
    Usage: stt [FILE] [--lang en|zh|auto] [--copy]
      FILE        any audio/video file; without one, record from the mic
                  until Enter
      --lang L    spoken language (default auto)
      --copy      also put the text in the clipboard
    EOF
    }
    file="" lang=auto copy=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --lang) lang="$2"; shift ;;
        --copy) copy=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "stt: unknown option $1" >&2; usage >&2; exit 2 ;;
        *)  file="$1" ;;
      esac
      shift
    done

    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    if [ -z "$file" ]; then
      file="$tmp/rec.wav"
      pw-record --rate 16000 --channels 1 "$file" &
      rec=$!
      echo "stt: recording -- press Enter to stop" >&2
      read -r _
      kill -INT "$rec"; wait "$rec" || true
    fi
    [ -s "$file" ] || { echo "stt: no audio" >&2; exit 1; }

    text=$(curl -fsS --max-time 900 http://127.0.0.1:8020/inference \
      -F "file=@$file" -F "language=$lang" -F "response_format=text" \
      -F "temperature=0.0") || { echo "stt: the Whisper server didn't answer" >&2; exit 1; }
    text=$(printf '%s' "$text" | sed 's/^[[:space:]]*//')
    printf '%s\n' "$text"
    [ "$copy" = 1 ] && printf '%s' "$text" | wl-copy
    exit 0
  '';
}
