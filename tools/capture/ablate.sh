#!/usr/bin/env bash
# Runs the ablation rows of tools/capture/ablate.gd, one Godot process per row, the whole list
# PASSES times (ABAB order: every row, then every row again).
#   GODOT=<console exe> ROUTE=<route.json> OUT=<dir> [TIME=night WEATHER=clear GRAPHICS=medium PASSES=2] \
#     tools/capture/ablate.sh
# On the shared PC run it inside the engine slot and the off-screen no_focus override.cfg.
set -u
cd "$(dirname "$0")/../.." || exit 1
ROWS="${ROWS:-baseline buildings kaiju_cubes kaiju_filler kaiju_cube_shadows ground_flat sun_shadows ssao ssil far_dof glow fx_hidden}"
for pass in $(seq 1 "${PASSES:-2}"); do
  for row in $ROWS; do
    APPDATA="$OUT/appdata_$row" timeout 900 "$GODOT" --path . --resolution 3840x2160 --windowed \
      --fixed-fps 60 --disable-vsync --script tools/capture/ablate.gd -- --row="$row" \
      --route-file="$ROUTE" --out="$OUT/pass$pass" --time="${TIME:-night}" \
      --weather="${WEATHER:-clear}" --graphics="${GRAPHICS:-medium}" 2>&1 | grep -E "ABLATE|SCRIPT ERROR|NVIDIA"
  done
done
