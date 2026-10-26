#!/usr/bin/env bash
# A/B for render plan item 8 (pooled dust, sparks and fire systems): the baseline route on the adult
# city, the pool OFF (--tune=render_opt.fx_pool=0) then ON, ABAB, one Godot process per run, then the
# per-phase comparison. Needs tools/capture/bench_frames.gd and bench_lib.gd and the CURRENT native
# DLL in native/bin.
#   GODOT=<console exe> ROUTE=<route.json> OUT=<dir> [TIME=night WEATHER=clear GRAPHICS=medium PASSES=2] \
#     tools/capture/bench_fx_pool.sh
# RUNS="off:1 on:1" runs just those (mode:pass); a caller that must take a turn on a shared machine
# before each run calls the script once per run, and RUNS=none only prints the comparison.
# On the shared PC: the no_focus override.cfg in the worktree root, the PC to itself (D-299: the caller
# holds C:/kt/BENCH_WINDOW_<role> and waits for zero other Godot). Each run prints "others=N" (other
# Godot processes at its start and the most seen during it: N above 0 voids it) and, for the ON runs, "FXPOOL peak/slots ..."
# (the most slots in use at once per kind: it re-sizes render_opt.fx_pool.slots).
# Flood guard: a run whose log passes FLOOD_BYTES (5 MB) has its own Godot stopped by PID and prints FLOOD
# (the engine's self_list error flood, freeze-fix #254).
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT}" "${ROUTE:?set ROUTE}" "${OUT:?set OUT}"
mkdir -p "$OUT"
FLOOD_BYTES="${FLOOD_BYTES:-5242880}"

# Process ids of the Godot runs whose command line holds `pattern` (this run's label: ours alone).
godot_pids() {
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'godot%'\" | Where-Object { \$_.CommandLine -like '*$1*' } | ForEach-Object { \$_.ProcessId }" | tr -d '\r'
}
# How many Godot runs (not the console wrappers) are going besides this label's.
others_now() {
  powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'godot%' and not Name like '%console%'\" | Where-Object { \$_.CommandLine -notlike '*$1*' }).Count" | tr -d '\r'
}

bench_run() { # mode pass
  local mode="$1" pass="$2" tune="" label="fxpool_$1_$2"
  local log="$OUT/${mode}_pass$pass.log"
  [ "$mode" = off ] && tune="--tune=render_opt.fx_pool=0"
  bash ~/.claude/tools/engine_slot.sh || return 3
  local others_start
  others_start=$(others_now "--label=$label ")
  APPDATA="$OUT/appdata_${mode}_$pass" timeout 1500 "$GODOT" \
    --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
    --script tools/capture/bench_frames.gd -- --time="${TIME:-night}" --weather="${WEATHER:-clear}" \
    --graphics="${GRAPHICS:-medium}" --route=replay --route-file="$ROUTE" --out="$OUT/${mode}_pass$pass" \
    --label="$label" $tune --fx-pool-report > "$log" 2>&1 &
  local run_pid=$! flood=0 others_max=0 now=0
  while kill -0 "$run_pid" 2> /dev/null; do
    sleep 10
    now=$(others_now "--label=$label ")
    [ "${now:-0}" -gt "$others_max" ] && others_max="$now"
    if [ "$(stat -c %s "$log" 2> /dev/null || echo 0)" -gt "$FLOOD_BYTES" ]; then
      flood=1
      for pid in $(godot_pids "--label=$label "); do
        powershell -NoProfile -Command "Stop-Process -Id $pid -Force"
      done
      break
    fi
  done
  wait "$run_pid" 2> /dev/null
  grep -E "BENCH_|FXPOOL|SCRIPT ERROR|NVIDIA" "$log" | head -40
  [ "$flood" = 1 ] && echo "FLOOD: $log passed $FLOOD_BYTES bytes; this run's Godot was stopped by PID (run void)"
  echo "RUN $mode:$pass others_start=$others_start others_max=$others_max flood=$flood"
}

runs="${RUNS:-}"
if [ -z "$runs" ]; then
  for pass in $(seq 1 "${PASSES:-2}"); do runs="$runs off:$pass on:$pass"; done
fi
for run in $runs; do
  [ "$run" = none ] && continue
  bench_run "${run%%:*}" "${run##*:}"
done
py -3 -I tools/capture/fx_pool_compare.py "$OUT"
