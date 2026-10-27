#!/usr/bin/env bash
# GPU cost of the P1c knobs: ONE timing run per call (a bench window holds the machine for one run).
# For a speed bar, prefer tools/capture/bench_driver.sh: it holds the window for every run, counts headless
# Godot too, voids and repeats a disturbed run, and reads the GPU ms line (wall time is CPU-bound and noisy).
#   GODOT=<console exe> OUT=<dir> tools/capture/p1c_gpu_cost.sh <run>
#   <run>: off | both (item 3: bar +0.05 ms)   cur | new (item 4: bar 0 +-0.02 ms), each optionally
#   with a _<n> suffix (off_1, new_2). The shipped look is the new grade, deband on, Medium sharpness
#   0.1 (D-285): "both" and "new" run it as is; "off" and "cur" switch each back to the old values.
# Gate (lead protocol, D-292): touch C:/kt/BENCH_WINDOW_perf-p1c only when no other C:/kt/BENCH_WINDOW*
# exists; then no WINDOWED Godot (headless ones are fine) and no League of Legends (tasklist,
# nvidia-smi) at two checks 20 s apart; one run; the window file and override.cfg go on exit.
# The mean frame time is appended to <OUT>/COST.txt (capture_one_look --frames=600, stage 3 night,
# Medium, 3840x2160, replayed route).
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT}" "${OUT:?set OUT}"
RUN="${1:?usage: p1c_gpu_cost.sh off|both|cur|new[_n]}"
ROUTE="${ROUTE:-C:/Users/DANTE/AppData/Local/Temp/claude/pb/route.json}"
WINDOW="C:/kt/BENCH_WINDOW_perf-p1c"
mkdir -p "$OUT"
case "${RUN%%_*}" in
  off) EXTRA=(--set=deband=false --tune=display.graphics.medium.fsr_sharpness=0.2) ;;
  both | new) EXTRA=() ;;
  cur) EXTRA=(--set=agx_contrast=1.25,post_contrast=1.3) ;;
  *) echo "unknown run $RUN"; exit 1 ;;
esac

others() {  # another bench window exists?
  ls C:/kt/BENCH_WINDOW* 2>/dev/null | grep -v "BENCH_WINDOW_perf-p1c" | grep -q .
}
busy() {  # 0 = something else is running (windowed Godot or League)
  local n
  n=$(powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -notmatch '--headless' }).Count")
  [ "$n" != 0 ] && return 0
  tasklist 2>/dev/null | grep -qi "League of Legends" && return 0
  nvidia-smi --query-compute-apps=name --format=csv,noheader 2>/dev/null | grep -qi league && return 0
  return 1
}
cleanup() { rm -f "$WINDOW"; [ -n "${MADE_CFG:-}" ] && rm -f override.cfg; }
trap cleanup EXIT

while others; do sleep 30; done  # only touch my window when nobody else holds one
touch "$WINDOW"
if others; then rm -f "$WINDOW"; exec "$0" "$@"; fi  # lost a race: start over
while true; do
  if ! busy; then
    sleep 20
    busy || break
  fi
  sleep 30
done
if [ ! -e override.cfg ]; then
  printf '[display]\n\nwindow/size/mode=0\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\n' > override.cfg
  MADE_CFG=1
fi
echo "== $RUN $(date +%H:%M:%S) ${EXTRA[*]:-}" | tee -a "$OUT/COST.txt"
APPDATA="$OUT/appdata_$RUN" timeout 900 "$GODOT" --path . --resolution 3840x2160 --windowed \
  --fixed-fps 60 --disable-vsync --script tools/capture/capture_one_look.gd -- --stage=3 \
  --graphics=medium --time=night --calm --route=replay --route-file="$ROUTE" --frames=600 \
  --out="$OUT" --label="$RUN" --tag=bench_p1c ${EXTRA[@]+"${EXTRA[@]}"} 2>&1 \
  | grep -E "ONEL frame|ONEL gpu|SCRIPT ERROR" | tee -a "$OUT/COST.txt"
