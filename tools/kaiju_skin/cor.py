"""Optimized centres of rotation for the voxel skin (Le & Hodgins 2016, "Real-time Skeletal Skinning
with Optimized Centers of Rotation"; director 2026-10-31: the thigh's linear blend collapses).

Each cube blended over two or more bones gets a centre of rotation c: the average of every cube's
rest centre, weighted by how alike its bone weights are to this cube's (the paper's similarity,
eq. 4-6, sigma SIGMA; the voxels stand in for its surface triangles, one unit of area each). The
shader (scenes/voxel_skin.gdshader) then moves the cube by the bones' blended rotation about c
and moves c itself by the linear blend, so the cube keeps its distance from the joint: no collapse.
A cube on one bone needs none (flag 0) and moves rigidly with it as before.

    block(centres, bones, weights)  -> the .vskin "CORS" block bake.py appends
    python tools/kaiju_skin/cor.py <assets/kaiju/name.vskin>   (prints the count and how far c lies)
"""
import gzip
import struct
import sys

import numpy as np

TAG = b"CORS"
SIGMA = 0.1  # the paper's kernel width
STEP = 0.01  # weight grouping for the kernel (u8 weights: below their resolution x 2.5)
MIN_SUPPORT = 1e-6  # below this total similarity a cube keeps the plain linear blend


def dense(bones, weights, nw):
    """Per cube its weights over all nw bones (rows sum to 1)."""
    out = np.zeros((len(bones), nw))
    for k in range(3):
        np.add.at(out, (np.arange(len(bones)), bones[:, k]), weights[:, k])
    return out / np.maximum(1e-9, out.sum(1, keepdims=True))


def centres_of_rotation(centres, bones, weights, nw):
    """(n, 3) centres of rotation and (n,) flags (1 = has one) for cubes at `centres` (rig units)
    with top-3 `bones` / `weights`. Cubes sharing one weight row share one centre, so the work is
    over unique rows."""
    w = dense(bones, weights, nw)
    rows, inv = np.unique(np.round(w, 6), axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    count = np.bincount(inv, minlength=len(rows)).astype(float)
    total = np.zeros((len(rows), 3))
    np.add.at(total, inv, centres)
    num = np.zeros((len(rows), 3))
    mass = np.zeros(len(rows))
    holds = [np.nonzero(rows[:, b] > 0.0)[0] for b in range(nw)]  # rows with weight on bone b
    for p in range(nw):
        for q in range(p + 1, nw):
            both = np.intersect1d(holds[p], holds[q], assume_unique=True)
            if len(both) > 0:
                _pair(rows[both, p], rows[both, q], both, count, total, num, mass)
    has = (mass > MIN_SUPPORT).astype(np.uint8)
    cor = num / np.maximum(mass, MIN_SUPPORT)[:, None]
    return cor[inv], has[inv]


def _pair(wp, wq, both, count, total, num, mass):
    """Adds bone pair (p, q)'s similarity term to every row on both bones. Rows are grouped by
    their (w_p, w_q) to STEP; the kernel runs between groups, so the cost is groups squared."""
    key = np.round(np.stack([wp, wq], 1) / STEP).astype(int)
    g, at = np.unique(key, axis=0, return_inverse=True)
    at = at.reshape(-1)
    gp, gq = g[:, 0] * STEP, g[:, 1] * STEP
    prod = wp * wq  # b_p b_q per row
    gpos = np.zeros((len(g), 3))
    np.add.at(gpos, at, prod[:, None] * total[both])
    gmass = np.bincount(at, prod * count[both], len(g))
    d = gp[:, None] * gq[None, :] - gq[:, None] * gp[None, :]
    k = np.exp(-(d * d) / (SIGMA * SIGMA))
    num[both] += prod[:, None] * (k @ gpos)[at]
    mass[both] += prod * (k @ gmass)[at]


def block(centres, bones, weights, nw):
    """The .vskin centre-of-rotation block: TAG, u32 count, per cube f32 x y z (rig units) and
    f32 flag."""
    cor, has = centres_of_rotation(centres, bones, weights, nw)
    rec = np.zeros((len(cor), 4), dtype="<f4")
    rec[:, :3], rec[:, 3] = cor, has
    return TAG + struct.pack("<I", len(cor)) + rec.tobytes()


def read_cells(path):
    """Cube centres (rig units), bones, weights (0..1) and the bone count from a .vskin."""
    raw = gzip.decompress(open(path, "rb").read())
    nw, v, n = struct.unpack_from("<HfI", raw, 16)
    rec = np.frombuffer(raw, dtype=np.dtype([("p", "<i2", 3), ("c", "u1", 3), ("f", "u1"), ("b", "u1", 3),
                                             ("w", "u1", 2)]), count=n, offset=26)
    centres = (rec["p"].astype(float) + np.array([0.0, 0.5, 0.0])) * v
    w = np.zeros((n, 3))
    w[:, :2] = rec["w"] / 255.0
    w[:, 2] = np.maximum(0.0, 1.0 - w[:, 0] - w[:, 1])
    return centres, rec["b"].astype(int), w, nw, v


if __name__ == "__main__":
    import time
    c, b, w, nw, v = read_cells(sys.argv[1])
    t = time.time()
    cor, has = centres_of_rotation(c, b, w, nw)
    off = np.linalg.norm(cor - c, axis=1)[has == 1] / v
    print(f"{len(c)} cubes, {has.sum()} with a centre, {time.time() - t:.1f} s; "
          f"centre from cube (voxels) median {np.median(off):.1f} p95 {np.percentile(off, 95):.1f}")
