"""Bakes each rigged kaiju's voxels into a skin for scenes/voxel_skin.gd (D-041: voxel cubes on a
smooth skin). Run by tools/kaiju_skin/bake_all.sh after any .kvox or .rig.json change:

    python tools/kaiju_skin/bake.py <rest.json from dump_rest.gd> <assets/kaiju dir>

For every kaiju in rest.json it reads <name>.kvox (the voxels and their bone split, from
rig_voxel.py) and writes <name>.vskin:
- the voxels moved into the rig's real rest pose (the arms the game lowers at load are lowered here,
  so the skin is never stretched from a T-pose), snapped back onto the grid;
- per voxel, up to 3 bones and weights: the bone split smoothed over the voxel lattice, blending only
  bones that form a joint (a thigh lying against the tail stays its own part);
- a filler: the exposed faces of the voxels near joints as one watertight surface, set a little
  inside the cubes, so a bending joint shows skin where cubes part, never sky.

.vskin is gzip of: "VSKN", u32 version, 8 bytes source stamp (the first 8 bytes of SHA-256 over the
.kvox then the .rig.json, so a test can tell a stale skin), u16 bones, f32 voxel, u32 cells, per cell i16 x y z,
u8 r g b, u8 flags (1 = mouth inside), u8 bone[3], u8 weight[2] (the third is the rest); u32 filler
vertices, per vertex f32 x y z (rig units), u8 r g b, u8 bone[3], u8 weight[2]; u32 indices, u32 each.
"""
import gzip
import hashlib
import json
import struct
import sys
from pathlib import Path

import numpy as np

VERSION = 2
LATTICE_PASSES = 12  # joint blend width, in voxel-lattice smoothing passes (look test round 2)
MIXED = 0.98  # a voxel whose main bone has less than this share is in a joint: it gets filler
FILL_INSET = 0.3  # voxels: the filler sits this far inside the cubes
MOUTH_RED = 1.35  # BipedHead.MOUTH_RED: the sculpt's pink mouth inside
MOUTH_BONES = ("head1", "jaw")
# Hinged parts that move as one rigid piece against their parent (a jaw, a mantis mandible): they
# never blend with it, so an open mouth keeps its mass and its teeth (lead review, PR #15).
HINGES = ("jaw", "mandible_l", "mandible_r")
DIRS = np.array([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)])


def read_kvox(path):
    data = path.read_bytes()
    assert data[:4] == b"KVOX", path
    version = struct.unpack_from("<I", data, 4)[0]
    if version >= 2:  # magic, version, poses, height, then the first pose's count and voxels
        n, off = struct.unpack_from("<I", data, 14)[0], 18
    else:  # magic, version, count, height, voxels
        n, off = struct.unpack_from("<I", data, 8)[0], 14
    rec = np.frombuffer(data, dtype=np.dtype([("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"),
                                              ("g", "u1"), ("b", "u1"), ("f", "u1")]), count=n, offset=off)
    return np.c_[rec["x"], rec["y"], rec["z"]].astype(int), np.c_[rec["r"], rec["g"], rec["b"]], rec["f"].astype(int)


def source_stamp(kdir, name):
    data = (kdir / f"{name}.kvox").read_bytes() + (kdir / f"{name}.rig.json").read_bytes()
    return hashlib.sha256(data).digest()[:8]


def top3(w):
    top = np.argsort(-w, axis=1)[:, :3]
    tw = np.take_along_axis(w, top, 1)
    tw /= np.maximum(1e-9, tw.sum(1, keepdims=True))
    q = np.round(tw[:, :2] * 255).astype(int)
    q[:, 1] = np.minimum(q[:, 1], 255 - q[:, 0])
    return top, q


def bake(name, rest, kdir, rig):
    cells, rgb, owner = read_kvox(kdir / f"{name}.kvox")
    bones = rest["bones"]
    names = [b["name"] for b in bones]
    nb = len(names)
    v = rest["voxel"]
    parents = {b["name"]: b["parent"] for b in rig["bones"]}
    related = np.eye(nb, dtype=bool)
    for i, n in enumerate(names):
        if parents.get(n) is not None:
            j = names.index(parents[n])
            related[i, j] = related[j, i] = n not in HINGES
    # Into the rest pose the game builds (rig units), and back onto the grid.
    xf = np.array([b["xform"] for b in bones])
    basis = xf[:, :9].reshape(-1, 3, 3).transpose(0, 2, 1)  # columns x, y, z
    origin, head = xf[:, 9:], np.array([b["head"] for b in bones])
    # A turned bone (the lowered arms) is sampled 8 times per voxel so the turned shell has no
    # pinholes once it is snapped back onto the grid; an unturned one moves whole cells.
    turned = np.abs(basis - np.eye(3)).max(axis=(1, 2)) > 1e-4
    src = np.arange(len(cells))
    many = np.where(turned[owner])[0]
    subs = [np.array(o) * 0.5 - 0.25 for o in np.ndindex(2, 2, 2)]
    src = np.concatenate([src] + [many] * len(subs))
    off = np.concatenate([np.zeros((len(cells), 3))] + [np.tile(o, (len(many), 1)) for o in subs])
    p = (cells[src] + off + np.array([0.0, 0.5, 0.0])) * v - head[owner[src]]
    moved = np.einsum("nij,nj->ni", basis[owner[src]], p) + origin[owner[src]]
    baked = np.round(moved / v - np.array([0.0, 0.5, 0.0])).astype(int)
    _, first = np.unique(baked, axis=0, return_index=True)
    keep = np.sort(first)
    cells, rgb, owner = baked[keep], rgb[src[keep]], owner[src[keep]]
    count = len(cells)
    index = {tuple(c): i for i, c in enumerate(cells)}
    nbr = np.array([[index.get((c[0] + d[0], c[1] + d[1], c[2] + d[2]), -1) for d in DIRS] for c in cells])
    # Lattice-smoothed weights, joint-related bones only.
    w = np.zeros((count, nb))
    w[np.arange(count), owner] = 1.0
    for _ in range(LATTICE_PASSES):
        acc = w.copy()
        cnt = np.ones((count, 1))
        for k in range(6):
            has = nbr[:, k] >= 0
            has[has] = related[owner[has], owner[nbr[has, k]]]
            acc[has] += w[nbr[has, k]]
            cnt[has] += 1
        w = acc / cnt
    cb, cq = top3(w)
    mouth_bones = [names.index(m) for m in MOUTH_BONES if m in names]
    r, g, b = rgb[:, 0].astype(float), rgb[:, 1].astype(float), rgb[:, 2].astype(float)
    mouth = np.isin(owner, mouth_bones) & (r > g * MOUTH_RED) & (r > b * MOUTH_RED)
    # Filler: exposed faces of joint voxels (and their neighbours), corners shared between voxels
    # whose bones form a joint, so it stays watertight as the joint bends.
    zone = w.max(1) < MIXED
    grow = zone.copy()
    for k in range(6):
        has = nbr[:, k] >= 0
        grow[has] |= zone[nbr[has, k]]
    corner_cells = {}
    for i in np.where(grow)[0]:
        c = cells[i]
        for o in np.ndindex(2, 2, 2):
            corner_cells.setdefault((c[0] + o[0], c[1] + o[1], c[2] + o[2]), []).append(i)
    vert_of, fpos, fnrm, fcol, fw, tris = {}, [], [], [], [], []
    for i in np.where(grow)[0]:
        c = cells[i]
        for k, d in enumerate(DIRS):
            if nbr[i, k] >= 0:
                continue
            n = d.astype(float)
            a = np.array([0.0, 1.0, 0.0]) if abs(n[1]) < 0.5 else np.array([1.0, 0.0, 0.0])
            u = np.cross(a, n) * 0.5
            vv = np.cross(n, u / np.linalg.norm(u)) * 0.5
            cc = c + np.array([0.0, 0.5, 0.0]) + n * 0.5
            quad = [cc - u - vv, cc + u - vv, cc + u + vv, cc - u + vv]
            ids = []
            for q in quad:
                lattice = (int(round(q[0] + 0.5)), int(round(q[1])), int(round(q[2] + 0.5)))
                key = (lattice, owner[i])
                if key not in vert_of:
                    mates = [j for j in corner_cells[lattice] if related[owner[i], owner[j]]]
                    vert_of[key] = len(fpos)
                    fpos.append(q)
                    fnrm.append(np.zeros(3))
                    fcol.append(rgb[mates].mean(0))
                    fw.append(w[mates].mean(0))
                ids.append(vert_of[key])
                fnrm[ids[-1]] = fnrm[ids[-1]] + n
            tris += [[ids[0], ids[2], ids[1]], [ids[0], ids[3], ids[2]]]
    fpos, fnrm = np.array(fpos).reshape(-1, 3), np.array(fnrm).reshape(-1, 3)
    fnrm /= np.maximum(1e-9, np.linalg.norm(fnrm, axis=1, keepdims=True))
    fpos = (fpos - fnrm * FILL_INSET) * v
    fb, fq = top3(np.array(fw).reshape(-1, nb)) if len(fw) else (np.zeros((0, 3), int), np.zeros((0, 2), int))
    cell_rec = np.zeros(count, dtype=np.dtype([("p", "<i2", 3), ("c", "u1", 3), ("f", "u1"), ("b", "u1", 3),
                                               ("w", "u1", 2)]))
    cell_rec["p"], cell_rec["c"], cell_rec["f"] = cells, rgb, mouth.astype(np.uint8)
    cell_rec["b"], cell_rec["w"] = cb, cq
    vert_rec = np.zeros(len(fpos), dtype=np.dtype([("p", "<f4", 3), ("c", "u1", 3), ("b", "u1", 3),
                                                   ("w", "u1", 2)]))
    vert_rec["p"], vert_rec["c"] = fpos, np.round(np.array(fcol).reshape(-1, 3)).astype(np.uint8)
    vert_rec["b"], vert_rec["w"] = fb, fq
    blob = b"VSKN" + struct.pack("<I", VERSION) + source_stamp(kdir, name)
    blob += struct.pack("<HfI", nb, v, count) + cell_rec.tobytes()
    blob += struct.pack("<I", len(fpos)) + vert_rec.tobytes()
    blob += struct.pack("<I", len(tris) * 3) + np.array(tris, dtype="<u4").tobytes()
    (kdir / f"{name}.vskin").write_bytes(gzip.compress(blob, 9))
    print(f"{name}: {count} voxels, {nb} bones, "
          f"filler {len(fpos)} vertices {len(tris)} triangles, {mouth.sum()} mouth voxels")


def main():
    rest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    kdir = Path(sys.argv[2])
    for name, entry in sorted(rest.items()):
        assert max(len(entry["bones"]), 1) <= 127, f"{name}: too many bones for the shader"
        rig = json.loads((kdir / f"{name}.rig.json").read_text(encoding="utf-8"))
        bake(name, entry, kdir, rig)


main()
