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
  - --connect <id> (a separate pass on the baked file, idempotent): the voxelised shell leaves parts
    that touch the rest only by an edge or a corner, or float. Under the sim's support rule
    (face-joined to the ground, sim/voxel_support.gd) those would fall on the first hit, so each
    such part gets the shortest 6-connected run of cells to the nearest other part (colour of the
    cell it grows from), until every part is joined to the ground layer. Added cells open the
    faces that face air, hide the faces of voxels they now cover, and mark their chunk structural.
    python tools/landmarks/bake.py --connect <id>
  - --pool <raw.kvox> <id> (a city building of data/city_buildings.json, D-256/D-257): the same
    bake into assets/city_buildings/<id>.kvox and its pool row (w, d, h, chunks, kvox,
    stretch_floor), after cropping the generated base slab (crop_plinth) and grading the sampled
    texture colours to the row's district palette (district_grade); then the --connect pass.
    python tools/landmarks/bake.py --pool <raw.kvox> <id>
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
## The city's building pool (Tripo heroes and fillers, D-256): rows in, baked shapes out.
POOL = os.path.join(ROOT, "data", "city_buildings.json")
## A base slab is at most this share of the model's height (crop_plinth).
PLINTH_SHARE = 0.03
## A sign's colour: saturation and value above these keep their brightness (district_grade).
SIGN_SAT = 0.45
SIGN_VAL = 0.55
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


def read_baked(path):
    """A baked file as (xyz int64 Nx3, rgb uint8 Nx3, flags uint8 N), in file order."""
    with open(path, "rb") as f:
        assert f.read(4) == b"KVOX", path
        f.read(8)  # version, frame count
        f.read(2)
        n = struct.unpack("<I", f.read(4))[0]
        raw = np.frombuffer(f.read(n * 10), dtype=np.dtype([
            ("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"), ("g", "u1"), ("b", "u1"), ("f", "u1")]))
    return (np.c_[raw["x"], raw["y"], raw["z"]].astype(np.int64),
            np.c_[raw["r"], raw["g"], raw["b"]].astype(np.uint8), raw["f"].copy())


def write_baked(path, h, xyz, rgb, flags):
    with open(path, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, h * RES))
        f.write(struct.pack("<I", len(xyz)))
        for (x, y, z), (r, g, b), m in zip(xyz, rgb, flags):
            f.write(struct.pack("<hhhBBBB", int(x), int(y), int(z), int(r), int(g), int(b), int(m)))


def label6(occ):
    """6-connected components of an occupancy grid: (labels, count), 0 = empty. Numpy only."""
    lab = np.zeros(occ.shape, np.int32)
    shape = np.array(occ.shape)
    count = 0
    for start in np.argwhere(occ):
        if lab[tuple(start)]:
            continue
        count += 1
        lab[tuple(start)] = count
        frontier = start[None, :]
        while len(frontier):
            grown = []
            for step in STEPS:
                n = frontier + np.array(step)
                n = n[np.all((n >= 0) & (n < shape), axis=1)]
                n = n[occ[n[:, 0], n[:, 1], n[:, 2]] & (lab[n[:, 0], n[:, 1], n[:, 2]] == 0)]
                if len(n):
                    lab[n[:, 0], n[:, 1], n[:, 2]] = count
                    grown.append(n)
            frontier = np.unique(np.vstack(grown), axis=0) if grown else frontier[:0]
    return lab, count


def bridge(lab, comp):
    """Shortest 6-run of empty cells from component `comp` to any other component's voxel:
    (cells to fill as Nx3, the voxel it grows from, the voxel it lands on)."""
    shape = np.array(lab.shape)
    seen = lab == comp
    parent = {}
    frontier = np.argwhere(seen)
    while True:
        nxt = []
        for step in STEPS:
            n = frontier + np.array(step)
            ok = np.all((n >= 0) & (n < shape), axis=1)
            n, base = n[ok], frontier[ok]
            fresh = ~seen[n[:, 0], n[:, 1], n[:, 2]]
            n, base = n[fresh], base[fresh]
            hit = lab[n[:, 0], n[:, 1], n[:, 2]] > 0
            if hit.any():
                i = int(np.argmax(hit))
                end = tuple(n[i])
                path = []
                cur = tuple(base[i])
                while cur in parent:  # walk back through the filled cells
                    path.append(cur)
                    cur = parent[cur]
                root = cur
                return np.array(path, dtype=np.int64).reshape(-1, 3), root, end
            keep = ~hit
            n, base = n[keep], base[keep]
            for c, b in zip(map(tuple, n), map(tuple, base)):
                if not seen[c]:
                    seen[c] = True
                    parent[c] = b
                    nxt.append(c)
        if not nxt:
            return None
        frontier = np.array(nxt, dtype=np.int64)


def connect(ident, pool=False):
    kvox_path, data_path, table = _target(ident, pool)
    path = kvox_path
    xyz, rgb, flags = read_baked(path)
    with open(data_path, encoding="utf-8") as f:
        data = json.load(f)
    shape = data[table][ident]
    w, d, h = shape["w"], shape["d"], shape["h"]
    dims = (w * RES, h * RES, d * RES)
    occ = np.zeros(dims, bool)
    occ[xyz[:, 0], xyz[:, 1], xyz[:, 2]] = True
    colour = {}
    for c, k in zip(map(tuple, xyz), rgb):
        colour[c] = tuple(int(v) for v in k)
    added = []
    before = None
    while True:
        lab, n = label6(occ)
        grounded = set(np.unique(lab[:, 0, :]).tolist()) - {0}
        loose = [c for c in range(1, n + 1) if c not in grounded]
        if before is None:
            sizes = np.bincount(lab.ravel())[1:]
            before = (len(loose), int(sum(sizes[c - 1] for c in loose)))
        if not loose:
            break
        # The smallest loose part first: it has the least rim to search.
        sizes = np.bincount(lab.ravel())
        comp = min(loose, key=lambda c: sizes[c])
        got = bridge(lab, comp)
        assert got is not None, "no way to join part %d" % comp
        fill, root, end = got
        for c in map(tuple, fill):
            occ[c] = True
            colour[c] = colour[root]
            added.append(c)
        if len(fill) == 0:  # already touching along a face: cannot happen after labelling
            raise AssertionError("part %d touches" % comp)
    print(f"{ident}: loose parts before {before[0]} ({before[1]} cells), added {len(added)} cells")
    if not added:
        return
    adds = np.array(added, dtype=np.int64)
    # Faces: an added cell shows the faces toward air (never its underside); a voxel it now
    # covers stops showing that face.
    order = {c: i for i, c in enumerate(map(tuple, xyz))}
    flags = flags.copy()
    new_flags = []
    for c in added:
        m = 0
        for k, step in enumerate(STEPS):
            n = (c[0] + step[0], c[1] + step[1], c[2] + step[2])
            inside = all(0 <= n[a] < dims[a] for a in range(3))
            if inside and occ[n]:
                if n in order:
                    flags[order[n]] &= ~np.uint8(1 << (k ^ 1))
            elif k != 3:
                m |= 1 << k
        new_flags.append(m)
    xyz = np.vstack([xyz, adds])
    rgb = np.vstack([rgb, np.array([colour[c] for c in added], dtype=np.uint8)])
    flags = np.concatenate([flags, np.array(new_flags, dtype=np.uint8)])
    write_baked(path, h, xyz, rgb, flags)
    layers = [list(layer) for layer in shape["chunks"]]
    for x, y, z in added:
        layers[y // RES][(z // RES) * w + x // RES] = "1"
    shape["chunks"] = ["".join(layer) for layer in layers]
    with open(data_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", sort_keys=True)
        f.write("\n")

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


def _target(ident, pool):
    """(kvox path, data file, table key) for a landmark or a city building of the pool."""
    if pool:
        return (os.path.join(ROOT, "assets", "city_buildings", ident + ".kvox"), POOL, "pool")
    return (os.path.join(ROOT, "assets", "landmarks", ident + ".kvox"), DATA, "landmarks")


def crop_plinth(cells, cols):
    """A generated building stands on a thin base slab wider than itself: keep only the voxels
    inside the plan of everything above the slab (PLINTH_SHARE of the height, at least 2 cells)."""
    top = cells[:, 1].max()
    above = cells[cells[:, 1] >= max(2, int(top * PLINTH_SHARE))]
    lo, hi = above.min(axis=0), above.max(axis=0)
    keep = ((cells[:, 0] >= lo[0]) & (cells[:, 0] <= hi[0])
            & (cells[:, 2] >= lo[2]) & (cells[:, 2] <= hi[2]))
    return cells[keep], cols[keep]


def _sat_val(rgb):
    """rgb (N x 3, 0..1) -> saturation, value."""
    mx, mn = rgb.max(axis=1), rgb.min(axis=1)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0), mx


def district_grade(cols, district):
    """Maps sampled texture colours to a district palette (D-257): each voxel moves `mix` of the
    way toward the palette colour nearest its own tint, at the voxel's own brightness, so the
    texture's light and dark detail stays; `dark` scales every voxel but the bright, saturated
    ones (signs), which `bright` scales instead (a neon strip: dark walls, bright signs)."""
    rgb = cols.astype(np.float64) / 255.0
    pal = np.array([[int(c[k:k + 2], 16) / 255.0 for k in (0, 2, 4)] for c in district["palette"]])
    luma = np.array([0.299, 0.587, 0.114])
    lum = rgb @ luma
    tint = rgb - lum[:, None]
    ptint = pal - (pal @ luma)[:, None]
    near = np.argmin(((tint[:, None, :] - ptint[None, :, :]) ** 2).sum(axis=2), axis=1)
    target = ptint[near] + lum[:, None]
    out = rgb + (target - rgb) * float(district.get("mix", 0.4))
    sat, val = _sat_val(rgb)
    sign = (sat > SIGN_SAT) & (val > SIGN_VAL)
    out[~sign] *= float(district.get("dark", 1.0))
    out[sign] = rgb[sign] * float(district.get("bright", 1.0))
    return np.clip(np.round(out * 255.0), 0, 255).astype(np.uint8)


def stretch_floor(occ, h):
    """The floor (sim layer) whose cells repeat unchanged in the floor above it, nearest the middle:
    the one a taller variant of the building repeats. -1 when no floor repeats."""
    best, away = -1, h
    for f in range(1, h - 2):
        a = occ[:, f * RES:(f + 1) * RES, :]
        b = occ[:, (f + 1) * RES:(f + 2) * RES, :]
        if a.any() and np.array_equal(a, b) and abs(f - h / 2) < away:
            best, away = f, abs(f - h / 2)
    return best


def bake(src, ident, ground=(), pool=False):
    cells, cols = read_kvox(src)
    if pool:
        with open(POOL, encoding="utf-8") as f:
            book = json.load(f)
        cells, cols = crop_plinth(cells, cols)
        cells[:, 1] -= cells[:, 1].min()
        cols = district_grade(cols, book["districts"][book["pool"][ident]["district"]])
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
    out_kvox, data_path, table = _target(ident, pool)
    os.makedirs(os.path.dirname(out_kvox), exist_ok=True)
    write_baked(out_kvox, h, cells[keep], cols[keep], masks[keep])
    data = {table: {}}
    if os.path.exists(data_path):
        with open(data_path, encoding="utf-8") as f:
            data = json.load(f)
    entry = data[table].get(ident, {}) if pool else {}
    entry.update({"w": w, "d": d, "h": h, "chunks": layers,
                  "kvox": "res://" + os.path.relpath(out_kvox, ROOT).replace(os.sep, "/")})
    if pool:
        entry["stretch_floor"] = stretch_floor(occ[1:-1, 1:-1, 1:-1], h)
    if ground:
        entry["ground"] = list(ground)
    data[table][ident] = entry
    with open(data_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", sort_keys=True)
        f.write("\n")
    print(f"baked {ident}: {w} x {d} x {h} chunks ({int(chunks.sum())} structural), "
          f"{int(keep.sum())} of {len(cells)} voxels drawn -> {out_kvox}")


if __name__ == "__main__":
    if sys.argv[1] == "--connect":
        connect(sys.argv[2], "--pool" in sys.argv)
        sys.exit(0)
    if sys.argv[1] == "--pool":  # a city building of data/city_buildings.json: bake, then connect
        bake(sys.argv[2], sys.argv[3], pool=True)
        connect(sys.argv[3], True)
        sys.exit(0)
    extra = [a[len("--ground="):].split(",") for a in sys.argv[3:] if a.startswith("--ground=")]
    bake(sys.argv[1], sys.argv[2], extra[0] if extra else [])


