#!/usr/bin/env bash
# Voxelises the D-404 Tripo boats (tuning.json boats.models) into assets/boats/<id>.kvox at their
# real height: round(metres_tall / metres_per_unit / voxel) cells. BLENDER overrides the Blender path.
#   tools/boats/bake.sh <glb_dir> [id ...]
set -u
ROOT="$(cd "$(dirname "$0")/../.." && (pwd -W 2>/dev/null || pwd))"
SRC="$1"
shift
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
mkdir -p "$ROOT/assets/boats"
IDS=("$@")
if [ ${#IDS[@]} -eq 0 ]; then
	mapfile -t IDS < <(python -c "import json; print('\n'.join(sorted(json.load(open('$ROOT/data/tuning.json'))['boats']['models'])))")
fi
for id in "${IDS[@]}"; do
	id="${id%$'\r'}"
	cells=$(python -c "
import json
b = json.load(open('$ROOT/data/tuning.json'))['boats']
print(max(2, round(b['models']['$id']['metres_tall'] / b['metres_per_unit'] / b['voxel'])))")
	cells="${cells%$'\r'}"
	timeout 600 "$BLENDER" -b --python "$ROOT/tools/blender/voxelize.py" -- "$SRC/$id.glb" "$ROOT/assets/boats/$id.kvox" "$cells" 2>&1 | grep -E "voxelized|Error|error" | tail -2
done
