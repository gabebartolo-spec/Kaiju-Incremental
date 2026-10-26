#!/usr/bin/env bash
# Render-plan batch P1c stills for the director: items 3 and 4, real Rampage, game camera, HUD as
# shipped, Medium preset, 3840x2160, local GPU (capture_one_look.gd, one Godot process per still).
#   GODOT=<console exe> OUT=<dir> [ROUTE=<route.json>] [ONLY=item3|item4] tools/capture/p1c_stills.sh
# Item 3 (4K clarity): night fog-heavy view (t=4), night lamp pools (t=12), dusk sky (t=4), each with
#   off / deband / sharp / both.   deband = look key `deband`; sharp = Medium's fsr_sharpness 0.1
#   (tuning display.graphics.medium; shipped 0.2).
# Item 4 (night darks keep their grain): night, dusk, morning, noon at t=12, cur / new.
#   new = agx_contrast 1.6 and post_contrast 1.0 (shipped 1.25 and 1.3).
# Each run waits for an engine slot and has its own APPDATA; the off-screen no_focus override.cfg is
# written (gitignored) if missing. Run only when the lead says Godot is back. Never opens a window
# that takes focus. Output: <OUT>/<set>_<variant>_t<NN>.png and a RUNS.txt of what was run.
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT to the console exe}" "${OUT:?set OUT to an output folder}"
ROUTE="${ROUTE:-C:/Users/DANTE/AppData/Local/Temp/claude/pb/route.json}"
SHARP=0.1
NEW_TONE="agx_contrast=1.6,post_contrast=1.0"
mkdir -p "$OUT"
if [ ! -e override.cfg ]; then
  printf '[display]\n\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(-4200, 0)\n' > override.cfg
  echo "wrote override.cfg (delete it when done)"
fi

shoot() {  # shoot <label> <time> <still-second> <extra capture args...>
  local label="$1" time="$2" at="$3"
  shift 3
  echo "$label time=$time t=$at $*" >> "$OUT/RUNS.txt"
  bash ~/.claude/tools/engine_slot.sh && APPDATA="$OUT/appdata_$label" timeout 900 "$GODOT" --path . \
    --resolution 3840x2160 --windowed --fixed-fps 60 --script tools/capture/capture_one_look.gd -- \
    --stage=3 --graphics=medium --time="$time" --calm --route=replay --route-file="$ROUTE" \
    --stills="$at" --out="$OUT" --label="$label" "$@" 2>&1 | grep -E "ONEL (shot|no image)|SCRIPT ERROR|NVIDIA"
}

if [ ! -e "$ROUTE" ]; then  # one recorded route, replayed by every still
  echo "no route at $ROUTE: recording one (20 s)"
  bash ~/.claude/tools/engine_slot.sh && APPDATA="$OUT/appdata_route" timeout 900 "$GODOT" --path . \
    --resolution 3840x2160 --windowed --fixed-fps 60 --script tools/capture/capture_one_look.gd -- \
    --stage=3 --graphics=medium --time=night --calm --route=record --route-file="$ROUTE" --seconds=20
fi

if [ "${ONLY:-item3}" != "item4" ]; then
  for view in "n3_fog night 4" "n3_lamps night 12" "d3_sky dusk 4"; do
    set -- $view
    shoot "$1_off" "$2" "$3"
    shoot "$1_deband" "$2" "$3" --set=deband=true
    shoot "$1_sharp" "$2" "$3" --tune=display.graphics.medium.fsr_sharpness=$SHARP
    shoot "$1_both" "$2" "$3" --set=deband=true --tune=display.graphics.medium.fsr_sharpness=$SHARP
  done
fi
if [ "${ONLY:-item4}" != "item3" ]; then
  for time in night dusk morning noon; do
    shoot "n4_${time}_cur" "$time" 12
    shoot "n4_${time}_new" "$time" 12 --set="$NEW_TONE"
  done
fi
echo "stills in $OUT; metrics: py -3 -I tools/capture/p1c_metrics.py $OUT"
