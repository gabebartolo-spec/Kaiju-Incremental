"""Voxelizes a jet (assets/source/vehicles/build_jets.py) for the game: the Body at the full
grain, the Wings (wings, tailplanes, fins) at half resolution with each column filled solid and
each cell drawn as 2x2x2 full cells, so swept edges step in runs of two voxels instead of a
one-voxel comb, and a wing never shows a hole. Same scale and centre fit as voxelize_parts.py,
whose .parts.json it also writes (one part, "body"), so VehicleParts loads it.

    blender -b --python tools/blender/vox_jet.py -- <in.glb> <out_base> <height_in_voxels>

Writes <out_base>_body.kvox and <out_base>.parts.json. At D-042's 2x grain (0.124 u a voxel,
the tank's and helicopter's) height = round(height_m * 2 / 3.3 / 0.124) + 1.
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


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, base, height = args[0], args[1], int(args[2])
    objects = vx.load(src)
    by_name = {o.name: o for o in objects}
    allp = np.concatenate([t[0] for t in vx.triangles(objects)])
    lo, hi = allp.min(axis=0), allp.max(axis=0)
    scale, centre, floor = (height - 1) / max(1e-6, hi[2] - lo[2]), (lo + hi) / 2.0, lo[2]
    cells = vx.voxelize(vx.triangles([by_name["Body"]]), (scale, centre, floor))
    coarse = vx.voxelize(vx.triangles([by_name["Wings"]]), (scale / 2.0, centre, floor))
    # Wings are thin slabs: fill each coarse column solid between its lowest and highest cell,
    # so a cell the shell sampling missed can't show as a dark hole in the wing's top.
    cols = {}
    for (x, y, z), acc in coarse.items():
        cols.setdefault((x, z), {})[y] = acc
    for (x, z), ys in cols.items():
        top = ys[max(ys)]
        for y in range(min(ys), max(ys) + 1):
            coarse.setdefault((x, y, z), list(top))
    for (x, y, z), acc in coarse.items():
        for dx in (0, 1):
            for dy in (0, 1):
                for dz in (0, 1):
                    # the wing wins: no stray body voxel (a pylon) shows through it
                    cells[(2 * x + dx, 2 * y + dy, 2 * z + dz)] = list(acc)
    out = f"{base}_body.kvox"
    write_kvox(out, cells, height)
    # The body's pivot as voxelize_parts.to_grid places it: the origin under the model.
    origin = np.array(by_name["Body"].matrix_world.translation)
    q = (origin - np.array([centre[0], centre[1], floor])) * scale
    pivot = [round(float(-q[0]) - 0.5, 3), round(float(q[2]), 3), round(float(q[1]) - 0.5, 3)]
    meta = {"height": height, "parts": {"body": {"kvox": Path(out).name, "pivot": pivot}}}
    Path(f"{base}.parts.json").write_text(json.dumps(meta, indent=1) + "\n")
    print(f"body: {len(cells)} voxels ({len(coarse)} half-res wing cells), pivot {pivot} -> {out}")


main()
