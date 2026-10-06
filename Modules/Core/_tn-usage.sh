# tn-usage: Akmon at a glance (`aku`), its usage log, and the weekly digest.
#   tn-usage            one screen: CPU, memory, GPU, pools, top processes
#   tn-usage -w [s]     same, redrawn every s seconds (default 1); q quits
#   tn-usage --log      append one sample to the CSV (tn-usage-log.timer)
#   tn-usage --week     7-day summary of the CSV (weekly email)

LOG=${TN_USAGE_LOG:-/var/lib/tn-usage/usage.csv}
STATE=${LOG%/*}/cpu.last
HEADER="ts,cpu_pct,mem_used_b,arc_b,gpu_pct,vram_mib,gpu_w,gpu_c,cpu_c,rpool_alloc_b,fast_alloc_b,uptime_s"
POOLS=(rpool fast)

# ── sampling ───────────────────────────────────────────────────────────────
# "total idle" jiffies; user..steal only (guest time is already in user)
cpu_snap() { awk '/^cpu /{ t=0; for (i=2; i<=9; i++) t+=$i; print t, $5+$6 }' /proc/stat; }
cpu_pct() { # "t1 i1" "t2 i2" -> busy %, empty if the counters went backwards (reboot)
  awk -v a="$1" -v b="$2" 'BEGIN { split(a,x," "); split(b,y," "); dt=y[1]-x[1]
    if (dt > 0) printf "%.1f", 100*(1-(y[2]-x[2])/dt) }'
}

# MemTotal, MemAvailable, SwapTotal, SwapFree in bytes
meminfo() { awk '/^(MemTotal|MemAvailable|SwapTotal|SwapFree):/{ printf "%s ", $2*1024 } END { print "" }' /proc/meminfo; }
arc_bytes() { awk '$1=="size"{ print $3 }' /proc/spl/kstat/zfs/arcstats 2>/dev/null || echo 0; }

# util%, vram used MiB, vram total MiB, temp C, power W, power limit W (NA when no GPU)
gpu() {
  nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit \
    --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ' | tr ',' ' ' \
    || echo "NA NA NA NA NA NA"
}

hwmon_temp() { # hwmon name -> temp1 in C
  local h
  for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] && [ -r "$h/temp1_input" ]; then
      echo $(( $(cat "$h/temp1_input") / 1000 )); return
    fi
  done
  echo NA
}

pool_alloc() { zpool list -Hp -o alloc "$1" 2>/dev/null || echo NA; }
uptime_s() { cut -d. -f1 /proc/uptime; }

# ── formatting ─────────────────────────────────────────────────────────────
# nord: frost / green / yellow / red / dim
C_F=$'\e[38;2;136;192;208m'; C_G=$'\e[38;2;163;190;140m'; C_Y=$'\e[38;2;235;203;139m'
C_R=$'\e[38;2;191;97;106m';  C_D=$'\e[38;2;76;86;106m';   C_B=$'\e[1m'; C_0=$'\e[0m'

gib() { awk -v b="$1" 'BEGIN { printf "%.1f", b/1073741824 }'; }
level() { # pct -> colour
  awk -v p="$1" -v g="$C_G" -v y="$C_Y" -v r="$C_R" 'BEGIN { print (p<60 ? g : p<85 ? y : r) }'
}
bar() { # pct [width]
  local w=${2:-24}
  awk -v p="$1" -v w="$w" -v c="$(level "$1")" -v d="$C_D" -v z="$C_0" 'BEGIN {
    n=int(p*w/100+0.5); if (n>w) n=w; if (n<0) n=0
    s=c; for (i=0;i<n;i++) s=s "█"; s=s d; for (;i<w;i++) s=s "░"; printf "%s%s", s, z }'
}
label() { printf '%s%-5s%s ' "$C_F$C_B" "$1" "$C_0"; }
dot() { if [ "$(systemctl is-active "$1" 2>/dev/null)" = active ]; then printf '%s●%s %s' "$C_G" "$C_0" "$2"; else printf '%s○ %s%s' "$C_D" "$3" "$C_0"; fi; }

# ── one screen ─────────────────────────────────────────────────────────────
render() {
  local tops s1 s2 cpu mem arc gpu_ pools
  tops=$(mktemp)
  # per-process CPU needs two frames; sample /proc/stat over the same second
  top -b -n2 -d1 -w 512 -o %CPU > "$tops" 2>/dev/null &
  s1=$(cpu_snap); sleep 1; s2=$(cpu_snap); wait
  cpu=$(cpu_pct "$s1" "$s2"); cpu=${cpu:-0}

  read -r mt ma st sf <<< "$(meminfo)"
  arc=$(arc_bytes)
  read -r gu vu vt gt gw gl <<< "$(gpu)"

  local used=$(( mt - ma )) apps
  apps=$(( used - arc )); [ "$apps" -lt 0 ] && apps=0
  local load fails up
  load=$(cut -d' ' -f1-3 /proc/loadavg)
  fails=$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l)
  up=$(uptime -p | sed 's/^up //')

  printf '%s%s%s  %s·  up %s  ·  load %s  ·  ' "$C_B" "$(hostname)" "$C_0" "$C_D" "$up" "$load"
  if [ "$fails" -eq 0 ]; then printf '%sno failed units%s\n\n' "$C_G" "$C_0"
  else printf '%s%s failed unit(s)%s\n\n' "$C_R" "$fails" "$C_0"; fi

  label CPU;  bar "$cpu"; printf ' %5.1f%%  %s threads  %s°C\n' "$cpu" "$(nproc)" "$(hwmon_temp coretemp)"
  local mp; mp=$(( used * 100 / mt ))
  label MEM;  bar "$mp"; printf ' %s / %s GiB  %s(apps %s, ZFS ARC %s)%s\n' \
    "$(gib "$used")" "$(gib "$mt")" "$C_D" "$(gib "$apps")" "$(gib "$arc")" "$C_0"
  if [ "$st" -gt 0 ]; then
    label SWAP; bar $(( (st - sf) * 100 / st )); printf ' %s / %s GiB zram\n' "$(gib $(( st - sf )))" "$(gib "$st")"
  fi
  echo

  if [ "$gu" != NA ]; then
    label GPU;  bar "$gu"; printf ' %5s%%  %s°C  %.0f / %.0f W\n' "$gu" "$gt" "$gw" "$gl"
    label VRAM; bar $(( vu * 100 / vt )); printf ' %.1f / %.1f GiB\n' \
      "$(awk -v m="$vu" 'BEGIN{print m/1024}')" "$(awk -v m="$vt" 'BEGIN{print m/1024}')"
    printf '%6s llama: %s   %s\n\n' "" "$(dot llama-cpp.service 'FIM loaded' 'FIM off (night?)')" \
      "$(dot llama-chat.service 'chat loaded' 'chat asleep')"
  fi

  local p name size alloc free frag cap health
  for p in "${POOLS[@]}"; do
    pools=$(zpool list -Hp -o name,size,alloc,free,frag,cap,health "$p" 2>/dev/null) || continue
    read -r name size alloc free frag cap health <<< "$pools"
    label "$( [ "$p" = "${POOLS[0]}" ] && echo POOL)"
    printf '%-6s ' "$name"; bar "$cap" 16
    printf ' %7s / %s GiB  frag %s%%  ' "$(gib "$alloc")" "$(gib "$size")" "$frag"
    if [ "$health" = ONLINE ]; then printf '%s%s%s\n' "$C_G" "$health" "$C_0"; else printf '%s%s%s\n' "$C_R" "$health" "$C_0"; fi
  done
  local h temps=""
  for h in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$h/name")" = nvme ] || continue
    temps+="$(basename "$(readlink -f "$h/device")") $(( $(cat "$h/temp1_input") / 1000 ))°C  "
  done
  [ -n "$temps" ] && { label ""; printf '%s\n' "$temps"; }
  echo

  # side by side: top CPU (second top frame) | top resident memory
  printf '%s%-38s %s%s\n' "$C_F$C_B" "TOP CPU" "TOP MEMORY" "$C_0"
  paste -d'\n' \
    <(awk '/^ *PID /{ f++; next } f==2 && NF>=12 && n<5 { printf "%6.1f%%  %-28s\n", $9, $12; n++ }' "$tops") \
    <(ps -eo rss=,comm= --sort=-rss | head -n5 | awk '{ printf "%6.1f GiB  %s\n", $1/1048576, $2 }') \
    | paste -d' ' - - | awk -F'\n' '{ print }' | sed 's/^/ /'
  rm -f "$tops"
}

watch_mode() {
  local every=${1:-1} frame k
  printf '\e[?25l'; trap 'printf "\e[?25h"' EXIT
  while :; do
    frame=$(render)
    printf '\e[H\e[2J%s\n%s  q to quit · refresh %ss%s' "$frame" "$C_D" "$every" "$C_0"
    if read -rsn1 -t "$every" k && [ "$k" = q ]; then break; fi
  done
  echo
}

# ── logging ────────────────────────────────────────────────────────────────
log_sample() {
  local now cpu prev s1
  mkdir -p "${LOG%/*}"
  [ -s "$LOG" ] || echo "$HEADER" > "$LOG"
  # CPU as the average since the previous sample, not a 1 s snapshot
  now=$(cpu_snap)
  prev=$(cat "$STATE" 2>/dev/null || true)
  cpu=$( [ -n "$prev" ] && cpu_pct "$prev" "$now" || true)
  if [ -z "$cpu" ]; then s1=$now; sleep 1; now=$(cpu_snap); cpu=$(cpu_pct "$s1" "$now"); fi
  echo "$now" > "$STATE"

  read -r mt ma _ _ <<< "$(meminfo)"
  read -r gu vu _ gt gw _ <<< "$(gpu)"
  echo "$(date +%s),$cpu,$(( mt - ma )),$(arc_bytes),$gu,$vu,$gw,$gt,$(hwmon_temp coretemp),$(pool_alloc rpool),$(pool_alloc fast),$(uptime_s)" >> "$LOG"

  # keep 90 days; only rewrite once the oldest row is past that
  local cutoff=$(( $(date +%s) - 90*86400 ))
  if [ "$(sed -n 2p "$LOG" | cut -d, -f1)" -lt "$cutoff" ]; then
    awk -F, -v c="$cutoff" 'NR==1 || $1>=c' "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
}

# ── weekly digest ──────────────────────────────────────────────────────────
week() {
  [ -s "$LOG" ] || { echo "No usage log yet ($LOG)."; return; }
  local since mt
  since=$(( $(date +%s) - 7*86400 ))
  read -r mt _ <<< "$(meminfo)"
  awk -F, -v since="$since" -v memtotal="$mt" '
    function stats(name, k, unit, scale,   n, i, v, s, a) {
      n = 0; for (i=1; i<=N; i++) if (col[k,i] != "" && col[k,i] != "NA") a[++n] = col[k,i]*scale
      if (!n) { printf "  %-14s       no data\n", name; return }
      s = 0; for (i=1; i<=n; i++) s += a[i]
      asort(a)
      printf "  %-14s %9.1f %9.1f %9.1f  %s\n", name, s/n, a[int(0.95*(n-1))+1], a[n], unit
    }
    NR==1 { next }
    $1 >= since {
      N++
      for (k=2; k<=NF; k++) col[k,N] = $k
      col["apps",N] = ($3 != "" && $4 != "") ? $3-$4 : ""
      if (N == 1) { t0 = $1; r0 = $10; f0 = $11 }
      t1 = $1; r1 = $10; f1 = $11
      if (prevup != "" && $12 < prevup) reboots++
      prevup = $12
      if ($7 != "NA" && $7 != "") kwh += $7 * 300 / 3600000
      if ($5 != "NA" && $5 > 10) busy++
    }
    END {
      if (!N) { print "No usage samples in the last 7 days."; exit }
      G = 1/1073741824
      printf "Akmon usage, last 7 days: %d samples every 5 min (%s to %s)\n", N, strftime("%a %d %b %H:%M", t0), strftime("%a %d %b %H:%M", t1)
      printf "  %-14s %9s %9s %9s\n", "", "mean", "p95", "max"
      stats("CPU",          2,  "%",   1)
      stats("CPU temp",     9,  "°C",  1)
      stats("RAM (apps)",   "apps", sprintf("GiB of %.0f", memtotal*G), G)
      stats("ZFS ARC",      4,  "GiB", G)
      stats("GPU",          5,  "%",   1)
      stats("VRAM",         6,  "GiB", 1/1024)
      stats("GPU power",    7,  "W",   1)
      stats("GPU temp",     8,  "°C",  1)
      printf "  GPU busy (>10%%) %.1f h, GPU energy %.1f kWh\n", busy*5/60, kwh
      printf "  rpool %.1f GiB used (%+.1f GiB this week)\n", r1*G, (r1-r0)*G
      printf "  fast  %.1f GiB used (%+.1f GiB this week)\n", f1*G, (f1-f0)*G
      printf "  Reboots: %d.  Coverage: %d of %d expected samples%s\n", reboots, N, 2016,
             (N < 1900 ? " (gaps: Akmon down or the logger stopped)" : "")
    }' "$LOG"
  local failed
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{ print $1 }' | paste -sd' ' -)
  echo "  Failed units now: ${failed:-none}"
}

case "${1:-}" in
  -w|--watch) watch_mode "${2:-1}" ;;
  --log)      log_sample ;;
  --week)     week ;;
  -h|--help)  sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' ;;
  "")         render ;;
  *)          echo "usage: tn-usage [-w [secs] | --log | --week]" >&2; exit 2 ;;
esac
