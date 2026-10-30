#!/usr/bin/env bash
# Voxelises the D-266 Tripo street props (tuning.json city.street_props.models) into
# assets/street_props/<id>.kvox: one Blender at a time.
#   tools/street_props/bake.sh <glb_dir> [id ...]
# Each prop is <glb_dir>/<id>_c.glb (the director's recoloured cut) or else <id>.glb, voxelised by
# tools/blender/voxelize.py at its real height: round(metres / metres_per_unit / voxel) cells.
# BLENDER overrides the Blender path.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && (pwd -W 2>/dev/null || pwd))"
SRC="$1"
shift
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
mkdir -p "$ROOT/assets/street_props"
IDS=("$@")
if [ ${#IDS[@]} -eq 0 ]; then
	mapfile -t IDS < <(python -c "import json; print('\n'.join(sorted(json.load(open('$ROOT/data/tuning.json'))['city']['street_props']['models'])))")
fi
for id in "${IDS[@]}"; do
	id="${id%$'\r'}"
	glb="$SRC/${id}_c.glb"
	[ -f "$glb" ] || glb="$SRC/$id.glb"
	cells=$(python -c "
import json
p = json.load(open('$ROOT/data/tuning.json'))['city']['street_props']
print(max(2, round(p['models']['$id']['metres'] / p['metres_per_unit'] / p['voxel'])))")
	cells="${cells%$'\r'}"
	timeout 600 "$BLENDER" -b --python "$ROOT/tools/blender/voxelize.py" -- "$glb" "$ROOT/assets/street_props/$id.kvox" "$cells" 2>&1 | grep -E "voxelized|Error|error" | tail -2
done
