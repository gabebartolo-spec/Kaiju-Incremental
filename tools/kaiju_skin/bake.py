"""Bakes each rigged kaiju's voxels into a skin for scenes/voxel_skin.gd (D-041: voxel cubes on a
smooth skin). Run by tools/kaiju_skin/bake_all.sh after any .kvox or .rig.json change:

    python tools/kaiju_skin/bake.py <rest.json from dump_rest.gd> <assets/kaiju dir>

For every kaiju in rest.json it reads <name>.kvox (the voxels and their bone split, from
rig_voxel.py) and writes <name>.vskin:
- the voxels moved into the rig's real rest pose (the arms the game lowers at load are lowered here,
  so the skin is never stretched from a T-pose), snapped back onto the grid;
- per voxel, up to 3 bones and weights: the bone split smoothed over the voxel lattice, blending only
  bones that form a joint (a thigh lying against the tail stays its own part); or, for a kaiju listed
  in assets/kaiju/skin_weights.json, a hand-made Blender skin (tools/blender/motion_test.py export:
  <x>.skin.json + <x>.skinw), sampled onto each voxel from the nearest weighted positions;
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
TISSUE = 0.05  # neighbours sharing at least this much bone weight are one tissue (blend_tissue)
FILL_INSET = 0.3  # voxels: the filler sits this far inside the cubes
MOUTH_RED = 1.35  # BipedHead.MOUTH_RED: the sculpt's pink mouth inside
MOUTH_BONES = ("head1", "jaw")
# Hinged parts that move as one rigid piece against their parent (a jaw, a mantis mandible): they
# never blend with it, so an open mouth keeps its mass and its teeth (lead review, PR #15).
HINGES = ("jaw", "mandible_l", "mandible_r")
SKIN_NEAREST = 4  # a voxel blends the weights of this many nearest Blender skin positions
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


def skin_files(kdir, name):
    """The Blender skin listed for this kaiju in skin_weights.json (skin_paths()), or []."""
    listing = kdir / "skin_weights.json"
    if not listing.exists():
        return []
    rel = json.loads(listing.read_text(encoding="utf-8")).get(name)
    return [] if rel is None else skin_paths(kdir / rel)


def source_stamp(kdir, name):
    """First 8 bytes of SHA-256 over the .kvox, the .rig.json and any Blender skin files (in that
    order; VoxelSkin.source_stamp() hashes the same bytes)."""
    data = (kdir / f"{name}.kvox").read_bytes() + (kdir / f"{name}.rig.json").read_bytes()
    for f in skin_files(kdir, name):
        data += f.read_bytes()
    return hashlib.sha256(data).digest()[:8]


def skin_paths(meta_path):
    """A Blender skin export's files: the .skin.json, its .skinw and, when present, its .skinf
    (the welded triangles, tools/kaiju_skin/skin_faces.py)."""
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    weights = meta_path.parent / meta["weights_file"]
    faces = weights.with_suffix(".skinf")
    return [meta_path, weights] + ([faces] if faces.exists() else [])


def closest_on_triangles(p, a, b, c):
    """Barycentric weights (n x 3) of the closest point to each p on its triangle a b c, and the
    squared distance (Ericson, Real-Time Collision Detection 5.1.5, vectorised)."""
    dot = lambda x, y: (x * y).sum(-1)
    ab, ac, ap, bp, cp = b - a, c - a, p - a, p - b, p - c
    d1, d2, d3, d4, d5, d6 = dot(ab, ap), dot(ac, ap), dot(ab, bp), dot(ac, bp), dot(ab, cp), dot(ac, cp)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    safe = lambda x: np.where(np.abs(x) > 1e-12, x, 1e-12)
    den = safe(va + vb + vc)
    v, w = vb / den, vc / den
    bary = np.stack([1 - v - w, v, w], -1)
    # The edges and corners, later regions first so the earlier tests win (Ericson's order).
    t = (d4 - d3) / safe((d4 - d3) + (d5 - d6))
    bary = np.where(((va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0))[..., None], np.stack([0 * t, 1 - t, t], -1), bary)
    t = d2 / safe(d2 - d6)
    bary = np.where(((vb <= 0) & (d2 >= 0) & (d6 <= 0))[..., None], np.stack([1 - t, 0 * t, t], -1), bary)
    corner = lambda i: np.eye(3)[i] * np.ones_like(d1)[..., None]
    bary = np.where(((d6 >= 0) & (d5 <= d6))[..., None], corner(2), bary)
    t = d1 / safe(d1 - d3)
    bary = np.where(((vc <= 0) & (d1 >= 0) & (d3 <= 0))[..., None], np.stack([1 - t, t, 0 * t], -1), bary)
    bary = np.where(((d3 >= 0) & (d4 <= d3))[..., None], corner(1), bary)
    bary = np.where(((d1 <= 0) & (d2 <= 0))[..., None], corner(0), bary)
    q = bary[..., 0:1] * a + bary[..., 1:2] * b + bary[..., 2:3] * c
    return bary, ((p - q) ** 2).sum(-1)


def sample_skin(meta_path, cells, names):
    """Per-voxel weights (cells x names, unnormalised) from a Blender skin export, each Blender bone
    counting for its "game" bone, and each cell's distance to the skin (metres). Each .kvox cell
    maps into the skin's space (kvox_cell_to_skin). With the export's triangles (.skinf) a cell takes
    the weights at the closest point on the skin (barycentric; the triangles tried are those around
    its SKIN_NEAREST * 2 nearest positions); without, it blends its SKIN_NEAREST nearest welded
    positions by inverse distance, which on a sparse mesh pulls weight across a crease."""
    files = skin_paths(meta_path)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    raw = files[1].read_bytes()
    assert raw[:4] == b"KSKW", files[1]
    count = struct.unpack_from("<I", raw, 8)[0]
    rec = np.frombuffer(raw, dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)], count=count, offset=14)
    to_game = np.array([names.index(b["game"]) for b in meta["bones"]])
    per_pos = np.zeros((count, len(names)))
    for slot in range(4):
        real = rec["b"][:, slot] != 255
        np.add.at(per_pos, (np.nonzero(real)[0], to_game[rec["b"][real, slot]]), rec["w"][real, slot])
    m = np.array(meta["kvox_cell_to_skin"], dtype=float)
    pts = (np.c_[cells, np.ones(len(cells))] @ m.T)[:, :3]
    skin_p = rec["p"].astype(float)
    tris = None
    if len(files) > 2:
        fraw = files[2].read_bytes()
        assert fraw[:4] == b"KSKF", files[2]
        tris = np.frombuffer(fraw, dtype="<u4", count=struct.unpack_from("<I", fraw, 8)[0] * 3,
                             offset=12).reshape(-1, 3).astype(np.int64)
        around = [[] for _ in range(count)]  # each position's triangles
        for t, tri in enumerate(tris):
            for i in tri:
                around[i].append(t)
        width = max(len(x) for x in around)
        around = np.array([x + [-1] * (width - len(x)) for x in around])
    w = np.zeros((len(cells), len(names)))
    gap = np.zeros(len(cells))
    k_near = SKIN_NEAREST * 2 if tris is not None else SKIN_NEAREST
    for lo in range(0, len(cells), 1024):
        chunk = pts[lo:lo + 1024]
        d2 = ((chunk[:, None, :] - skin_p[None, :, :]) ** 2).sum(-1)
        near = np.argpartition(d2, k_near, axis=1)[:, :k_near]
        if tris is None:
            dist = np.sqrt(np.take_along_axis(d2, near, 1))
            gap[lo:lo + len(chunk)] = dist.min(1)
            inv = 1.0 / (dist + 1e-3) ** 2
            w[lo:lo + len(chunk)] = (per_pos[near] * inv[..., None]).sum(1)
            continue
        cand = around[near].reshape(len(chunk), -1)
        ok = cand >= 0
        tri = tris[np.where(ok, cand, 0)]
        bary, dd = closest_on_triangles(chunk[:, None, :], skin_p[tri[..., 0]], skin_p[tri[..., 1]],
                                        skin_p[tri[..., 2]])
        best = np.argmin(np.where(ok, dd, np.inf), axis=1)
        row = np.arange(len(chunk))
        bt, bb = tri[row, best], bary[row, best]
        gap[lo:lo + len(chunk)] = np.sqrt(dd[row, best])
        w[lo:lo + len(chunk)] = (per_pos[bt] * bb[..., None]).sum(1)
    return np.maximum(w, 0.0), gap


def blender_weights(kdir, name, cells, owner, names):
    """Per-voxel weights (cells x bones) from the Blender skin listed for this kaiju, or None.
    Hinges stay rigid: a voxel the .kvox gives to the jaw is all jaw, and no other voxel takes any
    jaw weight (the .kvox draws the mouth line: tools/kaiju_skin/rig_from_skin.py)."""
    files = skin_files(kdir, name)
    if not files:
        return None
    w, _ = sample_skin(files[0], cells, names)
    for hinge in (h for h in HINGES if h in names):
        j = names.index(hinge)
        mine = owner == j
        w[:, j] = 0.0
        w[mine] = 0.0
        w[mine, j] = 1.0
    empty = w.sum(1) <= 0  # only jaw-weighted positions nearby: keep the .kvox bone
    w[empty, owner[empty]] = 1.0
    return w / w.sum(1, keepdims=True)


def own_only(w, kvox_owner, names, blend):
    """Blender weights with the listed bones (rig.json "skin_blend": {"own_only": [...]}) taken
    off every voxel the .kvox does not give them: a shortened arm's forearm and hand once lay
    against the belly in the Blender skin, and lifting it tore the belly open."""
    if not blend or not blend.get("own_only"):
        return w
    w = w.copy()
    for bone in blend["own_only"]:
        j = names.index(bone)
        w[kvox_owner != j, j] = 0.0
    empty = w.sum(1) <= 0
    w[empty, kvox_owner[empty]] = 1.0
    return w / w.sum(1, keepdims=True)


def blend_pairs(w, owner, nbr, names, blend):
    """Blender weights smoothed over the voxel lattice across the listed joints only (rig.json
    "skin_blend": {"pairs": [[bone, bone], ...], "passes": n}), so the skin there bends instead of
    parting: the young croc's chest tore open under a lifted arm (lead review 2026-10-25)."""
    if not blend:
        return w
    pair = np.zeros((len(names), len(names)), dtype=bool)
    for a, b in blend.get("pairs", []):
        i, j = names.index(a), names.index(b)
        pair[i, j] = pair[j, i] = pair[i, i] = pair[j, j] = True
    for _ in range(int(blend["passes"])):
        acc = w.copy()
        cnt = np.ones((len(w), 1))
        for k in range(6):
            has = nbr[:, k] >= 0
            has[has] = pair[owner[has], owner[nbr[has, k]]]
            acc[has] += w[nbr[has, k]]
            cnt[has] += 1
        w = acc / cnt
    return w


def tissue(w, nbr):
    """(cells x 6) True where a voxel and its neighbour are one tissue: they share bone weight (a
    forearm resting on the chest shares none, and parts from it; a jaw never blends)."""
    link = np.zeros(nbr.shape, dtype=bool)
    for k in range(6):
        has = nbr[:, k] >= 0
        link[has, k] = (w[has] * w[nbr[has, k]]).sum(1) > TISSUE
    return link


def blend_tissue(w, nbr, blend):
    """Weights smoothed over the voxel lattice wherever neighbours are one tissue (rig.json
    "skin_blend": {"tissue_passes": n}): the Blender weights jump from voxel to voxel enough that
    neighbours drift apart as the body moves, and the director saw it ("theres slits in the model
    when he moves", 2026-10-25)."""
    if not blend or not blend.get("tissue_passes"):
        return w
    link = tissue(w, nbr)
    for _ in range(int(blend["tissue_passes"])):
        acc = w.copy()
        cnt = np.ones((len(w), 1))
        for k in range(6):
            has = link[:, k]
            acc[has] += w[nbr[has, k]]
            cnt[has] += 1
        w = acc / cnt
    return w


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
    from_blender = blender_weights(kdir, name, cells, owner, names)
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
    # With Blender weights a voxel moves by its blend of bones (a soft shoulder: moved by its main
    # bone alone, the top of the shoulder swung down with the arm and left a hole, croc titan).
    turned = np.abs(basis - np.eye(3)).max(axis=(1, 2)) > 1e-4
    src = np.arange(len(cells))
    many = np.where(turned[owner] if from_blender is None else (from_blender[:, turned] > 0).any(1))[0]
    subs = [np.array(o) * 0.5 - 0.25 for o in np.ndindex(2, 2, 2)]
    src = np.concatenate([src] + [many] * len(subs))
    off = np.concatenate([np.zeros((len(cells), 3))] + [np.tile(o, (len(many), 1)) for o in subs])
    at = (cells[src] + off + np.array([0.0, 0.5, 0.0])) * v
    if from_blender is None:
        moved = np.einsum("nij,nj->ni", basis[owner[src]], at - head[owner[src]]) + origin[owner[src]]
    else:
        moved = np.zeros_like(at)
        for b in np.where(from_blender.any(0))[0]:
            moved += from_blender[src, b:b + 1] * ((at - head[b]) @ basis[b].T + origin[b])
    baked = np.round(moved / v - np.array([0.0, 0.5, 0.0])).astype(int)
    _, first = np.unique(baked, axis=0, return_index=True)
    keep = np.sort(first)
    cells, rgb, owner = baked[keep], rgb[src[keep]], owner[src[keep]]
    kvox_owner = owner  # the mouth test reads the .kvox split, whatever the weights
    count = len(cells)
    index = {tuple(c): i for i, c in enumerate(cells)}
    nbr = np.array([[index.get((c[0] + d[0], c[1] + d[1], c[2] + d[2]), -1) for d in DIRS] for c in cells])
    # Lattice-smoothed weights, joint-related bones only; or the Blender skin's, as they are (the
    # filler then pairs voxels by their main bone).
    w = np.zeros((count, nb))
    w[np.arange(count), owner] = 1.0
    if from_blender is not None:
        w = from_blender[src[keep]]
        owner = np.argmax(w, axis=1)
        w = own_only(w, kvox_owner, names, rig.get("skin_blend"))
        owner = np.argmax(w, axis=1)
        w = blend_pairs(w, owner, nbr, names, rig.get("skin_blend"))
        w = blend_tissue(w, nbr, rig.get("skin_blend"))
    for _ in range(LATTICE_PASSES if from_blender is None else 0):
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
    mouth = np.isin(kvox_owner, mouth_bones) & (r > g * MOUTH_RED) & (r > b * MOUTH_RED)
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
    print(f"{name}: {count} voxels, {nb} bones, weights {'Blender skin' if from_blender is not None else 'lattice'}, "
          f"filler {len(fpos)} vertices {len(tris)} triangles, {mouth.sum()} mouth voxels")


def main():
    rest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    kdir = Path(sys.argv[2])
    for name, entry in sorted(rest.items()):
        assert max(len(entry["bones"]), 1) <= 127, f"{name}: too many bones for the shader"
        rig = json.loads((kdir / f"{name}.rig.json").read_text(encoding="utf-8"))
        bake(name, entry, kdir, rig)


if __name__ == "__main__":
    main()
