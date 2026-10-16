# `call-rec`: record the focused screen with both sides of a call -- the
# default mic and whatever plays on the default output -- into
# ~/Videos/Calls/call-<date>_<time>.mkv. Ctrl+C stops. mkv so a crash or a
# dead battery still leaves a playable file.
{ writeShellApplication, wf-recorder, pulseaudio, hyprland, jq, coreutils }:
writeShellApplication {
  name = "call-rec";
  runtimeInputs = [ wf-recorder pulseaudio hyprland jq coreutils ];
  text = ''
    dir="$HOME/Videos/Calls"
    mkdir -p "$dir"
    file="$dir/call-$(date +%F_%H%M).mkv"

    # wf-recorder takes one audio source: a null sink with the mic and the
    # output's monitor looped into it, recorded from its own monitor
    sink=$(pactl get-default-sink)
    src=$(pactl get-default-source)
    null=$(pactl load-module module-null-sink sink_name=callrec sink_properties=device.description=call-rec)
    mic=$(pactl load-module module-loopback source="$src" sink=callrec latency_msec=30)
    spk=$(pactl load-module module-loopback source="$sink.monitor" sink=callrec latency_msec=30)
    trap 'pactl unload-module "$spk"; pactl unload-module "$mic"; pactl unload-module "$null"' EXIT

    output=$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused)).name')
    echo "call-rec: recording $output to $file -- Ctrl+C stops" >&2
    wf-recorder -o "$output" --audio=callrec.monitor \
      -c libx264 -p preset=veryfast -p crf=28 -f "$file" >/dev/null 2>&1 || true
    echo "call-rec: saved $file" >&2
  '';
}
