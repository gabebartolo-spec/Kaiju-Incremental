"""Voxel lower-lid flaps for a skin with lid_lo_l / lid_lo_r bones (D-190 blinks, D-335 lid bones), added to the
.kvox, each voxel owned by its lid bone, which bake.py keeps rigid (HINGES). On its own it replaces a rigged .kvox's lid
voxels and touches no other record (adding lids never re-rigs a kaiju); rig_from_skin.py calls it after a rig:

    python tools/kaiju_skin/lid_flaps.py <name.kvox> <x.skin.json>

A lower lid is a thin rigid spherical shell about its bone's head (the pivot, `depth` inside the eye). Closed, the
shell lies over the eye just outside its voxels; at rest it is turned `open` degrees about the lid's axis, into the
head, where no camera sees it. A blink turns the bone by `open` about that axis and the shell covers the eye. The
shell is built at rest on the kvox grid (so the closed lid is the same lattice turned): a cell is lid when its closed
image lies in the cap (`half` degrees each way about the closing axis, `over` more past the top, `lat` to each side)
and in the band `band` voxels thick that starts `gap` voxels outside the eye's surface along that direction (the first
empty cell seen from outside: surfaces()) and never nearer than the rig flap (`depth` * DEPTH_GAP). A cell that would
sit on a voxel or show at rest (a ray from it in any of 26 directions leaves the grid) is dropped. Each lid voxel
takes the colour of the nearest non-eye voxel one lid height below its closed place (the cheek under the eye).

The lid frame (the rig's, tools/blender lid build): pivot = the bone head, n = towards its tail, up = world up made
square to n, axis = n x up; a positive turn about the axis carries n towards up. Parameters come from the skin
header's "lid_flaps" block (lengths in skin units, angles in degrees, band and gap in voxels):
    {"depth": 2.13, "open": 100, "half": 30, "over": 16, "lat": 40, "band": 1.8, "gap": 0.9}
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bake  # noqa: E402

LIDS = ("lid_lo_l", "lid_lo_r")
DEPTH_GAP = 1.1  # the rig flap's radius: depth plus a tenth (its GAP)
REACH_OUT = 8.0  # skin units: the cube of cells around a pivot that may hold its lid
SURFACE_REACH = 6.0  # skin units: how far from a pivot the eye's surface is looked for
STEP = 6  # samples per voxel along a direction when looking for it
ENCLOSE_PUSH = 0.51  # voxels: an enclosure ray starts just outside its own cell
EYE_AMBER = (70, 15, 40)  # an eye voxel: red over this, red over green by this, blue under this (amber iris) ...
EYE_BLACK = 40  # ... or r + g + b under this (pupil)
RECORD = np.dtype([("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"), ("g", "u1"), ("b", "u1"), ("f", "u1")])


def rot(axis, deg):
    """Rotation matrix about a unit axis (Rodrigues)."""
    a = np.radians(deg)
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + np.sin(a) * k + (1 - np.cos(a)) * k @ k


def lid_frame(bone):
    """(pivot, n, up, axis) of a skin bone, in skin units."""
    piv = np.array(bone["head"], float)
    n = np.array(bone["tail"], float) - piv
    n /= np.linalg.norm(n)
    up = np.array([0.0, 1.0, 0.0]) - n * n[1]
    up /= np.linalg.norm(up)
    return piv, n, up, np.cross(n, up)


class Grid:
    """The kvox cells as a bool grid; cell centre in skin units = m @ (cell, 1) (kvox_cell_to_skin)."""

    def __init__(self, m, cells):
        self.m, self.inv, self.v = m, np.linalg.inv(m), float(m[0, 0])
        self.lo = cells.min(0) - 2
        self.occ = np.zeros(cells.max(0) + 3 - self.lo, bool)
        self.occ[tuple((cells - self.lo).T)] = True

    def cell(self, p):
        return np.floor((np.c_[p, np.ones(len(p))] @ self.inv.T)[:, :3] + 0.5).astype(int)

    def centre(self, c):
        return (np.c_[c, np.ones(len(c))] @ self.m.T)[:, :3]

    def filled(self, c):
        k = c - self.lo
        inb = np.all((k >= 0) & (k < self.occ.shape), axis=1)
        out = np.zeros(len(c), bool)
        out[inb] = self.occ[tuple(k[inb].T)]
        return out

    def hits(self, o, d):
        """Whether each ray o + t d (skin units, d unit) meets a voxel inside the grid (exact grid traversal)."""
        oc = (o - self.m[:3, 3]) / self.v + 0.5 - self.lo  # cell k spans [k, k + 1)
        cell = np.floor(oc).astype(int)
        step = np.where(d >= 0, 1, -1)
        with np.errstate(divide="ignore"):
            inv = np.where(np.abs(d) > 1e-12, 1.0 / np.abs(d), np.inf)
        tnext = np.where(d >= 0, cell + 1 - oc, oc - cell) * inv
        shape = np.array(self.occ.shape)
        hit = np.zeros(len(o), bool)
        alive = np.ones(len(o), bool)
        while alive.any():
            ids = np.nonzero(alive)[0]
            c = cell[ids]
            inb = np.all((c >= 0) & (c < shape), axis=1)
            h = np.zeros(len(ids), bool)
            h[inb] = self.occ[tuple(c[inb].T)]
            hit[ids[h]] = True
            alive[ids[h | ~inb]] = False
            ids = ids[~h & inb]
            if len(ids):
                k = np.argmin(tnext[ids], axis=1)
                cell[ids, k] += step[ids, k]
                tnext[ids, k] += inv[ids, k]
        return hit


def enclosed(grid, cells):
    """True for each cell from which every one of 26 rays (faces, edges, corners) meets a voxel."""
    dirs = np.array([d for d in np.ndindex(3, 3, 3) if d != (1, 1, 1)], float) - 1
    dirs /= np.linalg.norm(dirs, axis=1, keepdims=True)
    o = np.repeat(grid.centre(cells), len(dirs), axis=0)
    d = np.tile(dirs, (len(cells), 1))
    return grid.hits(o + d * ENCLOSE_PUSH * grid.v, d).reshape(len(cells), -1).all(1)


def surfaces(grid, piv, dirs):
    """Per direction from the pivot, the distance to the first empty cell that a ray from it leaves the grid (the eye's
    outer surface, or past a brow over it; a flood fill from outside would leak in through a hollow shell's pinholes),
    or SURFACE_REACH when there is none that near."""
    ts = np.arange(0.0, SURFACE_REACH, grid.v / STEP)
    c = grid.cell((piv[None, None] + dirs[:, None] * ts[None, :, None]).reshape(-1, 3))
    uc, back = np.unique(c, axis=0, return_inverse=True)
    out = ~grid.filled(uc)
    out[out] = ~enclosed(grid, uc[out])
    o = out[back.ravel()].reshape(len(dirs), len(ts))
    return np.where(o.any(1), ts[np.argmax(o, axis=1)], SURFACE_REACH)


def eye_voxels(rgb):
    r, g, b = (rgb[:, i].astype(int) for i in range(3))
    amber = (r > EYE_AMBER[0]) & (r > g + EYE_AMBER[1]) & (b < EYE_AMBER[2])
    return amber | (r + g + b < EYE_BLACK)


def one_lid(grid, bone, p):
    """Rest cells of one lid and their closed places (skin units)."""
    piv, n, up, ax = lid_frame(bone)
    closing = rot(ax, p["open"])
    span = int(np.ceil(REACH_OUT / grid.v))
    box = np.stack(np.meshgrid(*[np.arange(-span, span + 1)] * 3, indexing="ij"), -1).reshape(-1, 3)
    cand = box + grid.cell(piv[None])[0]
    shut = piv + (grid.centre(cand) - piv) @ closing.T
    rel = shut - piv
    rho = np.linalg.norm(rel, axis=1)
    dn = rel / np.maximum(rho[:, None], 1e-9)
    th = np.degrees(np.arctan2(dn @ up, dn @ n))
    ps = np.degrees(-np.arcsin(np.clip(dn @ ax, -1.0, 1.0)))
    cone = (th >= -p["half"]) & (th <= p["half"] + p["over"]) & (np.abs(ps) <= p["lat"]) & (rho < REACH_OUT)
    idx = np.nonzero(cone)[0]
    rin = np.maximum(p["depth"] * DEPTH_GAP, surfaces(grid, piv, dn[idx]) + p["gap"] * grid.v)
    keep = idx[(rho[idx] >= rin) & (rho[idx] <= rin + p["band"] * grid.v)]
    cells = cand[keep]
    ok = ~grid.filled(cells) & enclosed(grid, cells)
    return cells[ok], shut[keep][ok], up, int((~ok).sum())


def make(meta, cells, rgb, names):
    """The lid voxels to add: (cells, rgb, owner index into names), and a one-line report. Empty without the bones or
    the skin header's lid_flaps block."""
    p = meta.get("lid_flaps")
    lids = [n for n in LIDS if n in names]
    none = np.zeros((0, 3), int), np.zeros((0, 3), np.uint8), np.zeros(0, int)
    if not p or not lids:
        return none + ("no lid flaps",)
    grid = Grid(np.array(meta["kvox_cell_to_skin"], float), cells)
    by_name = {b["name"]: b for b in meta["bones"]}
    piv = np.array([by_name[n]["head"] for n in lids], float)
    close = np.linalg.norm(grid.centre(cells)[:, None] - piv[None], axis=2).min(1) < 2 * REACH_OUT
    src = np.nonzero(~eye_voxels(rgb) & close)[0]
    src_p = grid.centre(cells[src])
    out_c, out_rgb, out_o, said = [], [], [], []
    for lid in lids:
        lc, shut, up, dropped = one_lid(grid, by_name[lid], p)
        under = shut - up * (np.ptp(shut @ up) if len(shut) else 0.0)  # one lid height down: the cheek
        near = np.array([src[np.argmin(np.sum((src_p - q) ** 2, axis=1))] for q in under], int)
        out_c.append(lc)
        out_rgb.append(rgb[near] if len(near) else np.zeros((0, 3), np.uint8))
        out_o.append(np.full(len(lc), names.index(lid)))
        said.append(f"{lid} {len(lc)} voxels ({dropped} dropped: on a voxel or seen at rest)")
    return np.concatenate(out_c), np.concatenate(out_rgb).astype(np.uint8), np.concatenate(out_o), "; ".join(said)


def lid_bones(names):
    """Indices of the lid flap bones in a skin's bone list: only lid voxels are ever owned by them."""
    return [names.index(n) for n in LIDS if n in names]


def write_kvox(path, data, cells, rgb, owner):
    """Writes a v2 .kvox (`data`, its bytes as read) with its first pose's records replaced by these (v2: count at byte
    14, records from 18, 10 bytes each, the bone last); the header and anything after the records stay as they were."""
    assert struct.unpack_from("<I", data, 4)[0] >= 2, path
    end = 18 + RECORD.itemsize * struct.unpack_from("<I", data, 14)[0]
    rec = np.zeros(len(cells), RECORD)
    rec["x"], rec["y"], rec["z"] = np.asarray(cells).T
    rec["r"], rec["g"], rec["b"] = np.asarray(rgb).T
    rec["f"] = owner
    path.write_bytes(bytes(data[:14]) + struct.pack("<I", len(cells)) + rec.tobytes() + bytes(data[end:]))


def apply(kvox_path, meta, names):
    """Replaces the .kvox's lid voxels with ones made from its other voxels (kept in order, owners untouched); returns
    the report."""
    data = kvox_path.read_bytes()
    cells, rgb, owner = bake.read_kvox(kvox_path)
    keep = ~np.isin(owner, lid_bones(names))
    cells, rgb, owner = cells[keep], rgb[keep], owner[keep]
    lc, lrgb, lown, said = make(meta, cells, rgb, names)
    write_kvox(kvox_path, data, np.r_[cells, lc], np.r_[rgb, lrgb], np.r_[owner, lown])
    return said


def main():
    import rig_from_skin  # the bone list (it imports this module)

    kvox_path, meta_path = Path(sys.argv[1]), Path(sys.argv[2])
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    print(f"{kvox_path.name}: {apply(kvox_path, meta, rig_from_skin.bone_names(meta))}")


if __name__ == "__main__":
    main()
