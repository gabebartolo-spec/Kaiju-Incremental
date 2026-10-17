#!/usr/bin/env bash
# Re-bakes every rigged kaiju's voxel skin (D-041, scenes/voxel_skin.gd). Run after any change to
# assets/kaiju/*.kvox, *.rig.json or KaijuRig's rest pose; the smoke tests fail on a stale skin.
#   GODOT=/path/to/godot bash tools/kaiju_skin/bake_all.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
PYTHON="${PYTHON:-python}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT
# Godot builds every rig the way the game does and writes its rest pose; Python bakes the skins.
APPDATA="$WORK" "$GODOT" --headless --path . --script tools/kaiju_skin/dump_rest.gd -- "$WORK/rest.json"
"$PYTHON" tools/kaiju_skin/bake.py "$WORK/rest.json" assets/kaiju
