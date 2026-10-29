#!/usr/bin/env bash
# Voxelises and bakes every row of data/city_buildings.json (D-256): one Blender at a time.
#   tools/landmarks/bake_pool.sh <glb_dir> [id ...]
# Each <glb_dir>/<id>.glb (the Tripo sources, kept outside the repo) is voxelised at its row's
# height (floors x 8 voxels, so the bake gives that many floors; floors from storeys, see the
# data file's note) with tools/blender/voxelize.py, then baked with tools/landmarks/bake.py --pool.
# A missing GLB is skipped and listed. BLENDER overrides the Blender path.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && (pwd -W 2>/dev/null || pwd))"
SRC="$1"
shift
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
TMP="$(mktemp -d)"
IDS=("$@")
if [ ${#IDS[@]} -eq 0 ]; then
	mapfile -t IDS < <(python -c "import json; print('\n'.join(sorted(json.load(open('$ROOT/data/city_buildings.json'))['pool'])))")
fi
missing=()
for id in "${IDS[@]}"; do
	id="${id%$'\r'}"
	if [ ! -f "$SRC/$id.glb" ]; then
		missing+=("$id")
		continue
	fi
	floors=$(python -c "
import json
b = json.load(open('$ROOT/data/city_buildings.json'))
r = b['pool']['$id']
print(r.get('floors') or max(b['min_floors'], round(r['storeys'] * b['tallest_floors'] / b['tallest_storeys'])))")
	floors="${floors%$'\r'}"
	timeout 1200 "$BLENDER" -b --factory-startup --python "$ROOT/tools/blender/voxelize.py" -- \
		"$SRC/$id.glb" "$TMP/$id.kvox" $((floors * 8)) > "$TMP/$id.log" 2>&1
	code=$?
	if [ $code -ne 0 ] || [ ! -f "$TMP/$id.kvox" ]; then
		echo "$id: voxelize failed ($code), log $TMP/$id.log"
		continue
	fi
	python "$ROOT/tools/landmarks/bake.py" --pool "$TMP/$id.kvox" "$id" | tr '\n' ' '
	echo "($floors floors)"
done
[ ${#missing[@]} -gt 0 ] && echo "missing GLB: ${missing[*]}"
exit 0
