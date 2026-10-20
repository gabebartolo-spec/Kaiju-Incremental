#!/bin/bash
# Phase B look test (b2-19), never merged: puts the whole game at half / today / double voxel
# density in this working tree. Run from the repo root: tools/capture/phase_b_overlay.sh half|today|double
# Kaiju, tank, heli and landmark models, the building voxel size (RES) and the carving grid come
# from the claude/vox-half and claude/vox-double branches (their re-baked assets); props, cars and
# people are scaled at run time with --prop-k= (0.5 / 1 / 2) after "--" (VoxelBuilder.prop_k).
set -e
mode="$1"
case "$mode" in
	half) src=origin/claude/vox-half; res=4 ;;
	double) src=origin/claude/vox-double; res=16 ;;
	today) src=HEAD; res=8 ;;
	*) echo "usage: $0 half|today|double"; exit 1 ;;
esac
paths="assets/kaiju assets/landmarks assets/vehicles data/landmarks.json tools/landmarks/bake.py scenes/building_voxels.gd"
git checkout "$src" -- $paths
git checkout HEAD -- data/tuning.json
sed -i "s/\"res\": 8,/\"res\": $res,/" data/tuning.json
# The branches left the facade patterns in cells of an 8-cell floor (rows r == 4, 7, columns q ==
# 0, 4 ...): map them back onto the 8-grid so a window, mullion or transom keeps its world size
# (identity at 8), and scale the glass frame's column bay and beam row with the floor height.
sed -i 's/var r := y % RES$/var r := floori(float(y % RES) * 8.0 \/ RES)/; s/var q := p % RES$/var q := floori(float(p % RES) * 8.0 \/ RES)/' scenes/building_voxels.gd
git checkout HEAD -- sim/glass_frame.gd
sed -i 's/y % res == 4/y % res == res >> 1/' sim/glass_frame.gd
sed -i "s/\"column_bay\": 8/\"column_bay\": $res/" data/tuning.json
git reset -q HEAD -- $paths data/tuning.json
echo "voxel density: $mode (destruction.res=$res)"
grep -n '"res"' data/tuning.json
grep -n "^const RES" scenes/building_voxels.gd
