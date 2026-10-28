#!/usr/bin/env bash
# The Phase 0 baseline runs, one after another, each only when no other GPU Godot is running
# (a windowed run, a --write-movie, a capture_ or bench_ script), checked twice 20 s apart.
# Every other Godot command line on the PC is logged at the start and end of each run.
#   GODOT=<console exe> ROUTE=<route.json> OUT=<dir> tools/capture/baseline_runs.sh bench|ablate
# bench:  runs A (night clear) and B (dusk rain) at Medium and High, twice each, ABAB.
# ablate: tools/capture/ablate.gd rows on run A at Medium, twice each.
# Needs the off-screen no_focus override.cfg in the project folder (see Kit.window_ok).
set -u
cd "$(dirname "$0")/../.." || exit 1
ENGINE_SLOT="$HOME/.claude/tools/engine_slot.sh"

others() {  # the non-console Godot processes' command lines, one per line
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'godot%' and not Name like '%console%'\" | ForEach-Object { \$_.CommandLine }" | tr -d '\r'
}
WINDOW=/c/kt/BENCH_WINDOW_perf-p0  # the shared bench-window file (D-287): it stops other builders' windowed launches
gpu_busy() {  # his game, another windowed Godot or another builder's bench window (headless Godot is fine, D-292)
  tasklist 2>/dev/null | grep -qi "League of Legends" && return 0  # his game: timings beside it are void
  nvidia-smi --query-compute-apps=process_name --format=csv,noheader 2>/dev/null | grep -qi "League" && return 0
  others | grep -v -- "--headless" | grep . >/dev/null && return 0
  # HELD_BY=gq: run as a gq speed job, whose dispatcher holds BENCH_WINDOW_gq for this run (not another's)
  ls /c/kt/BENCH_WINDOW* 2>/dev/null | grep -v "BENCH_WINDOW_perf-p0" | grep -v "BENCH_WINDOW_${HELD_BY:-perf-p0}$" \n    | grep . >/dev/null && return 0
  return 1
}
wait_free() {  # take the bench window only when nothing else holds it; check twice, 20 s apart
  while true; do
    if ! gpu_busy; then
      touch "$WINDOW"
      sleep 20
      if ! gpu_busy; then return 0; fi
      rm -f "$WINDOW"
    fi
    sleep 30
  done
}
godot_run() {  # label, script, args...
  local label="$1" script="$2"
  if [ -n "${ONLY:-}" ] && ! echo " $ONLY " | grep -q " $label "; then return 0; fi
  shift 2
  bash "$ENGINE_SLOT" || return 3
  wait_free
  echo "=== $label start $(date +%T); other Godot processes:"; others | cut -c1-220
  APPDATA="$OUT/appdata_$label" timeout 1500 "$GODOT" --path . --resolution 3840x2160 --windowed \
    --fixed-fps 60 --disable-vsync --script "$script" -- "$@" 2>&1 | tee "$OUT/$label.log" \
    | grep -E "BENCH|ABLATE|SCRIPT ERROR|NVIDIA|refusing"
  rm -f "$WINDOW"
  echo "=== $label end $(date +%T); other Godot processes:"; others | cut -c1-220
}

mkdir -p "$OUT"
case "${1:-bench}" in
  bench)
    for pass in 1 2; do
      for cfg in "A night clear medium" "A night clear high" "B dusk rain medium" "B dusk rain high"; do
        set -- $cfg
        godot_run "${1}_${4}_$pass" tools/capture/bench_frames.gd --route-file="$ROUTE" \
          --time="$2" --weather="$3" --graphics="$4" --out="$OUT" --label="${1}_${4}_$pass"
      done
    done ;;
  ablate)
    ROWS="${ROWS:-baseline buildings kaiju_cubes kaiju_filler kaiju_cube_shadows ground_flat sun_shadows ssao ssil far_dof glow fx_hidden}"
    for pass in 1 2; do
      for row in $ROWS; do
        godot_run "ablate_${row}_$pass" tools/capture/ablate.gd --row="$row" --route-file="$ROUTE" \
          --time="${TIME:-night}" --weather="${WEATHER:-clear}" --graphics="${GRAPHICS:-medium}" \
          --out="$OUT/pass$pass"
      done
    done ;;
esac
