"""Turns a landmark's raw voxel shell (tools/blender/voxelize.py) into what the game loads:
assets/landmarks/<id>.kvox for presentation and its structural chunk mask in data/landmarks.json
for the sim, so a landmark breaks chunk by chunk like every other building.

    python tools/landmarks/bake.py <raw.kvox> <id> [--ground=3f8f3a,4fa346]

The raw shell is baked at 8 voxels per floor (BuildingVoxels.RES): voxelize.py with height
round(model_height * 8) + 1. This step:
  - moves the voxels into building-local cells: x in [0, w*8), z in [0, d*8), y from 0, centred on
    a footprint of w x d whole sim units (h floors);
  - finds the air reachable from outside the model (a flood from the border) and keeps only the
    voxels that touch it, each with a 6-bit mask of its faces open to that air, in the .kvox flags
    byte (bit k = BuildingMesher.NEIGHBOURS[k]: -x, +x, +y, -y, -z, +z). The mesher draws exactly
    those faces: a closed volume's inside is never drawn, as a building's hollow is not;
  - marks a chunk (one sim unit, one floor) as part of the structure when any cell in it is not
    outside air: a voxel, or air sealed inside the model. The sim builds only those chunks;
  - --ground lists colours (a pitch) that LandmarkVoxels also lays flat on the ground, so the
    ground under them stays that colour once their chunks are broken.
Pure Python + numpy.
"""
import json
import os
import struct
import sys

import numpy as np

RES = 8
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "data", "landmarks.json")
STEPS = [(-1, 0, 0), (1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, -1), (0, 0, 1)]


def read_kvox(path):
    with open(path, "rb") as f:
        assert f.read(4) == b"KVOX", path
        version = struct.unpack("<I", f.read(4))[0]
        assert version == 2, "expects a one-frame version 2 file from voxelize.py"
        f.read(4)  # frame count
        f.read(2)  # height
        n = struct.unpack("<I", f.read(4))[0]
        raw = np.frombuffer(f.read(n * 10), dtype=np.dtype([
            ("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"), ("g", "u1"), ("b", "u1"), ("f", "u1")]))
    cells = np.c_[raw["x"], raw["y"], raw["z"]].astype(np.int64)
    cols = np.c_[raw["r"], raw["g"], raw["b"]].astype(np.uint8)
    return cells, cols


def outside_air(occ):
    """Air cells reachable from the padded border, by repeated 6-way growth through air."""
    air = ~occ
    out = np.zeros_like(occ)
    out[0, :, :] = out[-1, :, :] = True
    out[:, :, 0] = out[:, :, -1] = True
    out[:, -1, :] = True  # open sky; the ground (y = 0) is not a way in
    out &= air
    while True:
        grown = out.copy()
        grown[1:, :, :] |= out[:-1, :, :]
        grown[:-1, :, :] |= out[1:, :, :]
        grown[:, 1:, :] |= out[:, :-1, :]
        grown[:, :-1, :] |= out[:, 1:, :]
        grown[:, :, 1:] |= out[:, :, :-1]
        grown[:, :, :-1] |= out[:, :, 1:]
        grown &= air
        if np.array_equal(grown, out):
            return out
        out = grown


def bake(src, ident, ground=()):
    cells, cols = read_kvox(src)
    lo, hi = cells.min(axis=0), cells.max(axis=0)
    span = hi - lo + 1
    w, d = int(-(-span[0] // RES)), int(-(-span[2] // RES))
    h = int(-(-(hi[1] + 1) // RES))
    shift = np.array([-lo[0] + (w * RES - span[0]) // 2, 0, -lo[2] + (d * RES - span[2]) // 2])
    cells = cells + shift
    cells[:, 1] = np.maximum(cells[:, 1], 0)
    # Padded grid: one cell of air all round, so the border flood reaches every outside face.
    occ = np.zeros((w * RES + 2, h * RES + 2, d * RES + 2), bool)
    p = cells + 1
    occ[p[:, 0], p[:, 1], p[:, 2]] = True
    outside = outside_air(occ)
    masks = np.zeros(len(cells), np.uint8)
    for k, step in enumerate(STEPS):
        n = p + np.array(step)
        masks |= outside[n[:, 0], n[:, 1], n[:, 2]].astype(np.uint8) << k
    masks &= ~np.uint8(1 << 3)  # the underside sits on the ground: never drawn
    keep = masks != 0
    # Chunks: any cell that is not outside air (voxel or sealed air) makes the chunk structural.
    solid = ~outside[1:-1, 1:-1, 1:-1]
    chunks = solid.reshape(w, RES, h, RES, d, RES).any(axis=(1, 3, 5))
    layers = []
    for y in range(h):
        layers.append("".join("1" if chunks[x, y, z] else "0" for z in range(d) for x in range(w)))
    out_kvox = os.path.join(ROOT, "assets", "landmarks", ident + ".kvox")
    os.makedirs(os.path.dirname(out_kvox), exist_ok=True)
    with open(out_kvox, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, h * RES))
        f.write(struct.pack("<I", int(keep.sum())))
        for (x, y, z), (r, g, b), m in zip(cells[keep], cols[keep], masks[keep]):
            f.write(struct.pack("<hhhBBBB", int(x), int(y), int(z), int(r), int(g), int(b), int(m)))
    data = {"landmarks": {}}
    if os.path.exists(DATA):
        with open(DATA, encoding="utf-8") as f:
            data = json.load(f)
    data["landmarks"][ident] = {"w": w, "d": d, "h": h, "kvox": "res://assets/landmarks/%s.kvox" % ident,
                                "chunks": layers}
    if ground:
        data["landmarks"][ident]["ground"] = list(ground)
    with open(DATA, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", sort_keys=True)
        f.write("\n")
    print(f"baked {ident}: {w} x {d} x {h} chunks ({int(chunks.sum())} structural), "
          f"{int(keep.sum())} of {len(cells)} voxels drawn -> {out_kvox}")


if __name__ == "__main__":
    extra = [a[len("--ground="):].split(",") for a in sys.argv[3:] if a.startswith("--ground=")]
    bake(sys.argv[1], sys.argv[2], extra[0] if extra else [])
