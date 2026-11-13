#!/usr/bin/env bash
# Re-bakes every rigged kaiju's voxel skin (D-041, scenes/voxel_skin.gd). Run after any change to
# assets/kaiju/*.kvox, *.rig.json or the rig's rest pose; the smoke tests fail on a stale skin.
#   bash tools/kaiju_skin/bake_all.sh
set -euo pipefail
PYTHON="${PYTHON:-python}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT
# slicebake builds every rig the way the game does and writes its rest pose (RestDump.cs, the C# of
# dump_rest.gd, no Godot); Python bakes the skins.
dotnet run --project tools/unity/slicebake -c Release -- --rest="$WORK/rest.json"
"$PYTHON" tools/kaiju_skin/bake.py "$WORK/rest.json" assets/kaiju
