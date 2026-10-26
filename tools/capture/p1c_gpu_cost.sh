#!/usr/bin/env bash
# GPU cost of the P1c knobs (timing bench: needs the machine alone). Each run waits until no other
# Godot runs and no League of Legends is running (tasklist, nvidia-smi), checked twice 20 s apart,
# then prints the mean frame time of capture_one_look --frames=600 (stage 3 night, Medium, 4K).
#   item 3: off vs deband+sharp (bar +0.05 ms)   item 4: old vs shipped tone (bar 0 +-0.02 ms)
#   The shipped look is the new grade, deband on, Medium sharpness 0.1 (D-285): "both" and "new"
#   run it as is; "off" and "cur" switch each back to the old values.
#   GODOT=<console exe> OUT=<dir> tools/capture/p1c_gpu_cost.sh   (two rounds, interleaved)
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT}" "${OUT:?set OUT}"
ROUTE="${ROUTE:-C:/Users/DANTE/AppData/Local/Temp/claude/pb/route.json}"
mkdir -p "$OUT"
if [ ! -e override.cfg ]; then  # the no-focus override.cfg, removed again when the run ends
  printf '[display]

window/size/mode=0
window/size/no_focus=true
window/size/initial_position_type=0
' > override.cfg
  trap 'rm -f override.cfg' EXIT
fi
busy() {  # 0 = something else is running
  local n
  n=$(powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\").Count")
  [ "$n" != 0 ] && return 0
  tasklist 2>/dev/null | grep -qi "League of Legends" && return 0
  nvidia-smi --query-compute-apps=name --format=csv,noheader 2>/dev/null | grep -qi league && return 0
  return 1
}
clear_twice() {
  while true; do
    if ! busy; then
      sleep 20
      busy || return 0
    fi
    sleep 30
  done
}
run() {  # run <label> <extra args>
  local label="$1"; shift
  clear_twice
  echo "== $label $(date +%H:%M:%S)" | tee -a "$OUT/COST.txt"
  APPDATA="$OUT/appdata_$label" timeout 900 "$GODOT" --path . --resolution 3840x2160 --windowed \
    --fixed-fps 60 --disable-vsync --script tools/capture/capture_one_look.gd -- --stage=3 \
    --graphics=medium --time=night --calm --route=replay --route-file="$ROUTE" --frames=600 \
    --out="$OUT" --label="$label" --tag=bench_p1c "$@" 2>&1 | grep -iE "frame|ms|SCRIPT ERROR" | tee -a "$OUT/COST.txt"
}
OLD_SHARP=display.graphics.medium.fsr_sharpness=0.2
for round in 1 2; do
  run "off_$round" --set=deband=false --tune=$OLD_SHARP
  run "both_$round"
  run "cur_$round" --set=agx_contrast=1.25,post_contrast=1.3
  run "new_$round"
done
