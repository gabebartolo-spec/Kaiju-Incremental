#!/usr/bin/env bash
# Night-sky stills for the director (2026-10-26 23:05: "maybe too much white in the blue"): the same
# night frame (same route, seed, camera, t=12 s), real game, 3840x2160, four looks:
#   A current   B fog_color 0c1428   C ambient 0.9   D both B and C
#   GODOT=<console exe> OUT=<dir> [ROUTE=<route.json>] tools/capture/night_sky_stills.sh
# Then: py -3 -I tools/capture/night_sky_label.py <OUT>  (burns the A/B/C/D label, prints luminance)
set -u
cd "$(dirname "$0")/../.." || exit 1
: "${GODOT:?set GODOT to the console exe}" "${OUT:?set OUT to an output folder}"
ROUTE="${ROUTE:-C:/Users/DANTE/AppData/Local/Temp/claude/pb/route.json}"
AT="${AT:-12}"
mkdir -p "$OUT"
if [ ! -e override.cfg ]; then
  printf '[display]\n\nwindow/size/mode=0\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\n' > override.cfg
fi
shoot() {  # shoot <letter> <extra capture args...>
  local l="$1"; shift
  echo "$l $*" >> "$OUT/RUNS.txt"
  bash ~/.claude/tools/engine_slot.sh && APPDATA="$OUT/appdata_$l" timeout 900 "$GODOT" --path . \
    --resolution 3840x2160 --windowed --fixed-fps 60 --script tools/capture/capture_one_look.gd -- \
    --stage=3 --graphics=medium --time=night --calm --route=replay --route-file="$ROUTE" \
    --stills="$AT" --out="$OUT" --label="night_$l" "$@" 2>&1 | grep -E "ONEL (shot|no image)|SCRIPT ERROR"
}
shoot A
shoot B --set=fog_color=0c1428
shoot C --set=ambient=0.9
shoot D --set=fog_color=0c1428,ambient=0.9
