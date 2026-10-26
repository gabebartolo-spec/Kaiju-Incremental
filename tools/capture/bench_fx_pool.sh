#!/usr/bin/env bash
# A/B for render plan item 8 (pooled dust, sparks and fire systems): the baseline route on the adult
# city, the pool OFF (--tune=render_opt.fx_pool=0) then ON, ABAB, one Godot process per run, then the
# per-phase comparison. Needs tools/capture/bench_frames.gd and bench_lib.gd (claude/perf-baseline,
# or main once merged) and the CURRENT native DLL in native/bin.
#   GODOT=<console exe> ROUTE=<route.json> OUT=<dir> [TIME=night WEATHER=clear GRAPHICS=medium PASSES=2] \
#     tools/capture/bench_fx_pool.sh
# On the shared PC: the off-screen no_focus override.cfg in the worktree root, no other GPU Godot
# running (check twice, 20 s apart). The ON runs print "FXPOOL peak/slots ..." (the most slots in use
# at once per kind): that is what re-sizes render_opt.fx_pool.slots.
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT}" "${ROUTE:?set ROUTE}" "${OUT:?set OUT}"
mkdir -p "$OUT"
for pass in $(seq 1 "${PASSES:-2}"); do
  for mode in off on; do
    tune=""
    [ "$mode" = off ] && tune="--tune=render_opt.fx_pool=0"
    bash ~/.claude/tools/engine_slot.sh && APPDATA="$OUT/appdata_${mode}_$pass" timeout 1500 "$GODOT" \
      --path . --resolution 3840x2160 --windowed --fixed-fps 60 --disable-vsync \
      --script tools/capture/bench_frames.gd -- --time="${TIME:-night}" --weather="${WEATHER:-clear}" \
      --graphics="${GRAPHICS:-medium}" --route=replay --route-file="$ROUTE" --out="$OUT/${mode}_pass$pass" \
      --label="fxpool_${mode}_$pass" $tune --fx-pool-report 2>&1 \
      | tee "$OUT/${mode}_pass$pass.log" | grep -E "BENCH_|BENCH native|FXPOOL|SCRIPT ERROR|NVIDIA"
  done
done
py -3 -I tools/capture/fx_pool_compare.py "$OUT"
