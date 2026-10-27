#!/usr/bin/env bash
# A/B for render plan item 8 (pooled dust, sparks and fire systems): the baseline route on the adult
# city, the pool OFF (--tune=render_opt.fx_pool=0) then ON, ABAB, one Godot process per run, then the
# per-phase comparison. Needs tools/capture/bench_frames.gd and bench_lib.gd and the CURRENT native
# DLL in native/bin (bench_lib refuses a DLL without KaijuSettle).
#   GODOT=<console exe> ROUTE=<route.json> OUT=<dir> [OWNER=perf-p2c TIME=night WEATHER=clear GRAPHICS=medium PASSES=2] \
#     bash C:/kt/wait_window.sh && bash tools/capture/bench_fx_pool.sh        (cwd = the worktree)
# RUNS="off:1 on:1" runs just those (mode:pass); RUNS=none only prints the comparison.
# D-299 (the PC to itself), the same protocol as tools/capture/bench_driver.sh: the script holds
# C:/kt/BENCH_WINDOW_<OWNER> from the first run to the last (touched every 4 s) and, before EVERY run, waits
# until no other Godot (headless included, console wrappers included) and no League of Legends is running, at
# two checks 20 s apart. While a run goes it samples the other-Godot count every 4 s: a run that saw others
# above 0 (or League, a flood, or no BENCH_END line) is VOID and is run again (up to 4 tries). It touches
# C:/kt/SPEED_LAST_END at the very end. The windowed run never takes focus (a no_focus override.cfg is made in
# the worktree root when none exists, and removed again).
# Each run prints "RUN <mode:pass> others_max=N ... VALID|VOID" and, for the ON runs, "FXPOOL peak/slots ..."
# (the most slots in use at once per kind: it re-sizes render_opt.fx_pool.slots). The DLL path and date are
# logged first: a bench on the wrong native library measures the script fallback.
# Flood guard: a run whose log passes FLOOD_BYTES (5 MB) has its own Godot stopped by PID and is VOID
# (the engine's self_list error flood, freeze-fix #254).
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT}" "${ROUTE:?set ROUTE}" "${OUT:?set OUT}"
mkdir -p "$OUT"
FLOOD_BYTES="${FLOOD_BYTES:-5242880}"
OWNER="${OWNER:-perf-p2c}"
WINDOW="C:/kt/BENCH_WINDOW_$OWNER"
TAG="--label=fxpool_" # every run of this script carries it: not "another" Godot
HELD=""
MADE_CFG=""

# Process ids of the Godot runs whose command line holds `pattern` (this script's runs: ours alone).
godot_pids() {
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'godot%'\" | Where-Object { \$_.CommandLine -like '*$1*' } | ForEach-Object { \$_.ProcessId }" | tr -d '\r'
}
# How many Godot processes are going that are not this script's runs (headless ones and wrappers count).
others_count() {
  powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'godot%'\" | Where-Object { \$_.CommandLine -notlike '*$TAG*' }).Count" | tr -d '\r\n '
}
league() {
  tasklist 2> /dev/null | grep -qi "League of Legends" && return 0
  nvidia-smi --query-compute-apps=name --format=csv,noheader 2> /dev/null | grep -qi league && return 0
  return 1
}
finish() {
  [ -n "$HELD" ] || return 0
  rm -f "$WINDOW"
  [ -n "$MADE_CFG" ] && rm -f override.cfg
  touch C:/kt/SPEED_LAST_END
}
trap finish EXIT

take_window() {
  if ls C:/kt/BENCH_WINDOW* 2> /dev/null | grep -v "BENCH_WINDOW_$OWNER" | grep -q .; then
    echo "another bench window is held; not starting (rerun behind wait_window.sh)"
    exit 3
  fi
  touch "$WINDOW"
  HELD=1
  if [ ! -e override.cfg ]; then # the windowed run must never take focus
    printf '[display]\n\nwindow/size/mode=0\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\n' > override.cfg
    MADE_CFG=1
  fi
  echo "== bench_fx_pool $(date '+%F %H:%M:%S') sha $(git rev-parse --short HEAD) owner $OWNER"
  for dll in native/bin/*.dll; do [ -e "$dll" ] && echo "   DLL $(pwd)/$dll $(date -r "$dll" '+%F %H:%M')"; done
}

# One try of one run; returns 0 when VALID, 1 when VOID.
bench_try() { # mode pass
  local mode="$1" pass="$2" tune="" label="fxpool_$1_$2"
  local log="$OUT/${mode}_pass$pass.log"
  [ "$mode" = off ] && tune="--tune=render_opt.fx_pool=0"
  while true; do # wait for silence, twice 20 s apart
    touch "$WINDOW"
    if [ "$(others_count)" = 0 ] && ! league; then
      sleep 20
      touch "$WINDOW"
      if [ "$(others_count)" = 0 ] && ! league; then break; fi
    fi
    sleep 15
  done
  rm -rf "$OUT/${mode}_pass$pass"
  bash ~/.claude/tools/engine_slot.sh || return 1
  echo "== $mode:$pass $(date +%H:%M:%S) $tune"
  APPDATA="$OUT/appdata_${mode}_$pass" timeout 1500 "$GODOT" \
    --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
    --script tools/capture/bench_frames.gd -- --time="${TIME:-night}" --weather="${WEATHER:-clear}" \
    --graphics="${GRAPHICS:-medium}" --route=replay --route-file="$ROUTE" --out="$OUT/${mode}_pass$pass" \
    --label="$label" $tune --fx-pool-report > "$log" 2>&1 &
  local run_pid=$! flood=0 others_max=0 now=0 lg=""
  while kill -0 "$run_pid" 2> /dev/null; do
    touch "$WINDOW"
    now=$(others_count)
    [ "${now:-0}" -gt "$others_max" ] 2> /dev/null && others_max="$now"
    league && lg="+League"
    if [ "$(stat -c %s "$log" 2> /dev/null || echo 0)" -gt "$FLOOD_BYTES" ]; then
      flood=1
      for pid in $(godot_pids "--label=$label "); do
        powershell -NoProfile -Command "Stop-Process -Id $pid -Force"
      done
      break
    fi
    sleep 4
  done
  wait "$run_pid" 2> /dev/null
  grep -E "BENCH_|FXPOOL|SCRIPT ERROR|NVIDIA" "$log" | head -40
  [ "$flood" = 1 ] && echo "FLOOD: $log passed $FLOOD_BYTES bytes; this run's Godot was stopped by PID"
  if [ "$others_max" = 0 ] && [ -z "$lg" ] && [ "$flood" = 0 ] && grep -q "BENCH_END" "$log"; then
    echo "RUN $mode:$pass others_max=0 VALID"
    return 0
  fi
  echo "RUN $mode:$pass others_max=$others_max$lg flood=$flood VOID"
  return 1
}

runs="${RUNS:-}"
if [ -z "$runs" ]; then
  for pass in $(seq 1 "${PASSES:-2}"); do runs="$runs off:$pass on:$pass"; done
fi
case "$runs" in
  none) ;;
  *) take_window ;;
esac
for run in $runs; do
  [ "$run" = none ] && continue
  for try in 1 2 3 4; do
    bench_try "${run%%:*}" "${run##*:}" && break
  done
done
py -3 -I tools/capture/fx_pool_compare.py "$OUT"
