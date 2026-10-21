"""Voxelizes a model made of moving parts (a tank's hull, turret and barrel) into one .kvox per
part on a shared grid, plus a <out>.parts.json with each part's pivot, so the game can turn and
elevate the parts about their real hinges.

    blender -b --python tools/blender/voxelize_parts.py -- <in.glb> <out_base> <height> \
        <part>=<Obj>[+<Obj>...] ...

e.g. hull=Hull+Tracks turret=Turret+CommanderMG barrel=Barrel. Writes <out_base>_<part>.kvox and
<out_base>.parts.json. The scale and centre come from the whole model (as voxelize.py), so the
parts line up. A part's pivot is its first object's origin, in voxel units on the game grid
(y up, facing -Z): a cell (x, y, z) sits at that cell * voxel, so pivot * voxel is the hinge.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import voxelize as vx  # noqa: E402  (Blender's bundled Python, the same folder)


def write_kvox(path, cells, height):
    with open(path, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, height))
        f.write(struct.pack("<I", len(cells)))
        for (x, y, z), (r, g, b, n) in cells.items():
            rgb = [int(max(0, min(255, round((v / n) ** (1 / 2.2) * 255)))) for v in (r, g, b)]
            f.write(struct.pack("<hhhBBBB", x, y, z, rgb[0], rgb[1], rgb[2], 0))


def to_grid(p, fit):
    """A Blender world point in game voxel units, matching the cell placement of voxelize()."""
    scale, centre, floor = fit
    q = (np.array(p) - np.array([centre[0], centre[1], floor])) * scale
    # a cell k covers [k, k + 1) and is drawn centred on k in x and z, on its base in y
    return [round(float(-q[0]) - 0.5, 3), round(float(q[2]), 3), round(float(q[1]) - 0.5, 3)]


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, base, height = args[0], args[1], int(args[2])
    groups = {}
    for spec in args[3:]:
        name, objs = spec.split("=", 1)
        groups[name] = objs.split("+")
    objects = vx.load(src)
    by_name = {o.name: o for o in objects}
    tris_all = vx.triangles(objects)
    allp = np.concatenate([t[0] for t in tris_all])
    lo, hi = allp.min(axis=0), allp.max(axis=0)
    fit = ((height - 1) / max(1e-6, hi[2] - lo[2]), (lo + hi) / 2.0, lo[2])
    meta = {"height": height, "parts": {}}
    for name, names in groups.items():
        missing = [n for n in names if n not in by_name]
        if missing:
            raise SystemExit(f"{name}: no object {missing} in {sorted(by_name)}")
        cells = vx.voxelize(vx.triangles([by_name[n] for n in names]), fit)
        out = f"{base}_{name}.kvox"
        write_kvox(out, cells, height)
        pivot = to_grid(by_name[names[0]].matrix_world.translation, fit)
        meta["parts"][name] = {"kvox": Path(out).name, "pivot": pivot}
        print(f"{name}: {len(cells)} voxels, pivot {pivot} -> {out}")
    Path(f"{base}.parts.json").write_text(json.dumps(meta, indent=1) + "\n")


main()
