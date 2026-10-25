"""Finds slits in a kaiju's voxel skin: places where, as it moves, you can see into the body.

    godot --headless --path . --script tools/kaiju_skin/dump_poses.gd -- poses.json
    python tools/kaiju_skin/slit_scan.py assets/kaiju/reptilian_baby.vskin poses.json [--step N]
        [--png DIR]

It poses the skin exactly as scenes/voxel_skin.gdshader and voxel_skin_fill.gdshader do (each cube's
centre moved by its blended bones, turned by its main bone, one size; the filler linearly skinned),
then draws it from several views (orthographic, a pixel = PIXEL voxels) with a depth buffer. A
pixel is a slit when the nearest thing there is a cube face that looks into the body at rest (a face
against another voxel or into the hollow inside), or nothing at all inside the silhouette (a hole
right through). Slit pixels are grouped, and each group is reported by its size in voxels.
Prints per tag (idle, walk, swipe_r, swipe_l) the worst frame, and the frames with a slit at least
MIN_VOXELS across; --png writes the worst views with the slits in red.
"""
import argparse
import gzip
import json
import struct
from pathlib import Path

import numpy as np
from scipy import ndimage

PIXEL = 0.5  # voxels per pixel
SAMPLES = 3  # per cube face edge
INSET = 0.99  # data/looks.json voxel_inset
MIN_VOXELS = 1.0
TISSUE = 0.05  # bake.py TISSUE
VALLEY_PX = 7  # a dip narrower than this many pixels is a slit, not a fold of the body
DIP_VOXELS = 0.5  # and at least this deep  # a slit group this wide (voxels) or more counts
DIRS = np.array([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)])
# Views: yaw (deg, 0 = in front of the kaiju, which faces -Z), pitch (deg, + = from above).
VIEWS = {"front": (0, 0), "front_high": (0, 30), "left": (90, 0), "right": (-90, 0),
         "front_left": (45, 15), "front_right": (-45, 15), "back": (180, 0)}


def read_vskin(path):
    raw = gzip.decompress(Path(path).read_bytes())
    assert raw[:4] == b"VSKN"
    nb, voxel, count = struct.unpack_from("<HfI", raw, 16)
    at = 26
    cdt = np.dtype([("p", "<i2", 3), ("c", "u1", 3), ("f", "u1"), ("b", "u1", 3), ("w", "u1", 2)])
    cells = np.frombuffer(raw, cdt, count, at)
    at += count * cdt.itemsize
    nv = struct.unpack_from("<I", raw, at)[0]
    at += 4
    vdt = np.dtype([("p", "<f4", 3), ("c", "u1", 3), ("b", "u1", 3), ("w", "u1", 2)])
    verts = np.frombuffer(raw, vdt, nv, at)
    at += nv * vdt.itemsize
    ni = struct.unpack_from("<I", raw, at)[0]
    tris = np.frombuffer(raw, "<u4", ni, at + 4).reshape(-1, 3).astype(int)
    return voxel, cells, verts, tris


def weights(b, w):
    w0, w1 = w[:, 0] / 255.0, w[:, 1] / 255.0
    return b.astype(int), np.c_[w0, w1, np.maximum(0.0, 1.0 - w0 - w1)]


def face_labels(p):
    """Per cell and direction: 0 = faces the open air, 1 = faces another voxel or the hollow."""
    lo = p.min(0) - 1
    shape = p.max(0) - lo + 2
    occ = np.zeros(shape, bool)
    q = p - lo
    occ[q[:, 0], q[:, 1], q[:, 2]] = True
    lab, _ = ndimage.label(~occ)
    border = np.unique(np.r_[lab[0].ravel(), lab[-1].ravel(), lab[:, 0].ravel(), lab[:, -1].ravel(),
                             lab[:, :, 0].ravel(), lab[:, :, -1].ravel()])
    outside = np.isin(lab, border[border > 0])
    out = np.zeros((len(p), 6), np.uint8)
    for k, d in enumerate(DIRS):
        n = q + d
        out[:, k] = ~outside[n[:, 0], n[:, 1], n[:, 2]]
    return out


def face_offsets():
    """(6 * SAMPLES^2, 3) points on a unit cube's faces (cube of size 1), and their face index."""
    g = (np.arange(SAMPLES) + 0.5) / SAMPLES - 0.5
    pts, face = [], []
    for k, d in enumerate(DIRS):
        a = np.array([0, 1, 0]) if d[1] == 0 else np.array([1, 0, 0])
        u = np.cross(a, d)
        v = np.cross(d, u)
        for s in g:
            for t in g:
                pts.append(d * 0.5 + u * s + v * t)
                face.append(k)
    return np.array(pts, float), np.array(face)


def view_basis(yaw, pitch):
    """Rows: screen right, screen up, toward the camera; the kaiju faces -Z."""
    y, p = np.radians(yaw), np.radians(pitch)
    toward = np.array([np.sin(y) * np.cos(p), np.sin(p), -np.cos(y) * np.cos(p)])
    right = np.cross([0.0, 1.0, 0.0], toward)
    right /= np.linalg.norm(right)
    up = np.cross(toward, right)
    return np.array([right, up, toward])


class Skin:
    def __init__(self, path):
        self.voxel, cells, verts, self.tris = read_vskin(path)
        rig = json.loads(Path(str(path).replace(".vskin", ".rig.json")).read_text(encoding="utf-8"))
        self.names = [b["name"] for b in rig["bones"]]
        self.turn_blend = rig.get("skin_blend", {}).get("turn", False) is True
        v = self.voxel
        self.centre = (cells["p"].astype(float) + [0.0, 0.5, 0.0]) * v
        self.cb, self.cw = weights(cells["b"], cells["w"])
        cell = cells["p"].astype(int)
        self.labels = face_labels(cell)
        self.offs, self.face = face_offsets()
        self.offs *= v * INSET
        # Faces worth drawing: every face of a voxel with a face in the open air or the hollow (a
        # face between two buried voxels stays under at least one more).
        index = {tuple(c): i for i, c in enumerate(cell)}
        nbr = np.array([[index.get(tuple(c + d), -1) for d in DIRS] for c in cell])
        exposed = (nbr < 0).any(1)
        # A face against a voxel of another part (no shared bone weight: a forearm resting on the
        # chest) is skin once they part, as tools/kaiju_skin/bake.py tissue() treats it.
        w = np.zeros((len(cell), len(self.names)))
        for k in range(3):
            np.add.at(w, (np.arange(len(cell)), self.cb[:, k]), self.cw[:, k])
        for k in range(6):
            has = nbr[:, k] >= 0
            touch = np.zeros(len(cell), dtype=bool)
            touch[has] = (w[has] * w[nbr[has, k]]).sum(1) <= TISSUE
            self.labels[touch, k] = 0
        self.ci, self.oi = np.nonzero(np.broadcast_to(exposed[:, None], (len(cell), len(self.face))))
        # The mouth line is drawn: the jaw's seam and the mouth's inside are not slits.
        jaw = self.names.index("jaw") if "jaw" in self.names else -1
        mouth = (cells["f"] & 1).astype(bool) | (self.cb[:, 0] == jaw)
        self.can_slit = self.labels[self.ci, self.face[self.oi]].astype(bool) & ~mouth[self.ci]
        self.fp = verts["p"].astype(float)
        self.fb, self.fw = weights(verts["b"], verts["w"])

    def pose(self, m):
        """Sample points, their outward normals and slit flags for one frame's bone matrices."""
        def blend(p, b, w):
            out = np.zeros_like(p)
            for i in range(3):
                mm = m[b[:, i]]
                out += w[:, i:i + 1] * (np.einsum("nij,nj->ni", mm[:, :3, :3], p) + mm[:, :3, 3])
            return out
        moved = blend(self.centre, self.cb, self.cw)
        if self.turn_blend:  # each cube turns with its blended bones (rig.json skin_blend.turn)
            basis = sum(self.cw[:, i, None, None] * m[self.cb[:, i], :3, :3] for i in range(3))
        else:  # with its main bone
            basis = m[self.cb[:, 0], :3, :3]
        ax = basis[:, :, 0] / np.linalg.norm(basis[:, :, 0], axis=1, keepdims=True)
        ay = basis[:, :, 1] - ax * np.sum(ax * basis[:, :, 1], 1, keepdims=True)
        ay /= np.linalg.norm(ay, axis=1, keepdims=True)
        t = np.stack([ax, ay, np.cross(ax, ay)], axis=2)[self.ci]  # columns
        pts = moved[self.ci] + np.einsum("nij,nj->ni", t, self.offs[self.oi])
        nrm = np.einsum("nij,nj->ni", t, DIRS[self.face[self.oi]].astype(float))
        slit = np.where(self.can_slit, self.cb[self.ci, 0], -1)
        fill = blend(self.fp, self.fb, self.fw)
        a, b, c = fill[self.tris[:, 0]], fill[self.tris[:, 1]], fill[self.tris[:, 2]]
        edge = np.maximum(np.linalg.norm(b - a, axis=1), np.maximum(np.linalg.norm(c - b, axis=1),
                                                                     np.linalg.norm(a - c, axis=1)))
        n_side = np.clip(np.ceil(edge / (self.voxel * PIXEL * 0.5)), 2, 24).astype(int)
        fpts = []
        for n in np.unique(n_side):
            sel = n_side == n
            i, j = np.meshgrid(np.arange(n + 1), np.arange(n + 1))
            keep = i + j <= n
            u, w = (i[keep] / n), (j[keep] / n)
            fpts.append((a[sel][:, None] * (1 - u - w)[None, :, None] + b[sel][:, None] * u[None, :, None]
                         + c[sel][:, None] * w[None, :, None]).reshape(-1, 3))
        fpts = np.concatenate(fpts) if fpts else np.zeros((0, 3))
        return pts, nrm, slit, fpts

    def render(self, posed, rot, lo, size):
        pts, nrm, slit, fpts = posed
        px = self.voxel * PIXEL
        facing = nrm @ rot[2] > -0.05
        p = pts[facing] @ rot.T
        s = slit[facing]
        f = fpts @ rot.T
        allp = np.r_[p, f]
        alls = np.r_[s, np.full(len(f), -1)]
        ix = np.floor((allp[:, 0] - lo[0]) / px).astype(int)
        iy = np.floor((allp[:, 1] - lo[1]) / px).astype(int)
        ok = (ix >= 0) & (iy >= 0) & (ix < size[0]) & (iy < size[1])
        ix, iy, depth, alls = ix[ok], iy[ok], allp[ok, 2], alls[ok]
        key = (iy * size[0] + ix).astype(np.int64)
        q = np.clip((depth.max() - depth) / px * 64.0, 0, 2**30 - 1).astype(np.int64)
        order = np.argsort(key * 2**30 + q)
        key, alls, depth = key[order], alls[order], depth[order]
        first = np.r_[True, key[1:] != key[:-1]]
        hit = np.zeros(size[0] * size[1], bool)
        bad = np.full(size[0] * size[1], -1)
        near = np.full(size[0] * size[1], -np.inf)
        hit[key[first]] = True
        bad[key[first]] = alls[first]
        near[key[first]] = depth[first]
        shape = (size[1], size[0])
        hit, bad, near = hit.reshape(shape), bad.reshape(shape), near.reshape(shape)
        holes = ndimage.binary_fill_holes(hit) & ~hit
        # A slit is a narrow dip: the surface on both sides is nearer than what shows here.
        floor = np.where(hit, near, near[hit].min() if hit.any() else 0.0)
        dip = ndimage.grey_closing(floor, size=(VALLEY_PX, VALLEY_PX)) - floor
        bad = np.where(dip > DIP_VOXELS * self.voxel, bad, -1)
        return hit, np.where(holes, len(self.names), bad)


def groups(bad, names):
    """[(width in voxels, bone)] per slit group; the bone whose voxels show most, or "hole"."""
    lab, n = ndimage.label(bad >= 0, structure=np.ones((3, 3)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        width = max(sl[0].stop - sl[0].start, sl[1].stop - sl[1].start) * PIXEL
        if width < MIN_VOXELS:
            continue
        b = bad[sl][lab[sl] == i + 1]
        top = np.bincount(b).argmax()
        out.append((width, names[top] if top < len(names) else "hole"))
    return out


SKIN = None


def scan(job):
    """One frame, every view: [(view, [(width, bone)])], and the views' masks when asked."""
    fi, m, rots, mid, reach, size = job
    posed = SKIN.pose(m)
    out = []
    for name, rot in rots.items():
        lo = (rot @ mid)[:2] - reach
        hit, bad = SKIN.render(posed, rot, lo, size)
        out.append((name, groups(bad, SKIN.names)))
    return fi, out


def init(path):
    global SKIN
    SKIN = Skin(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vskin")
    ap.add_argument("poses")
    ap.add_argument("--step", type=int, default=1)
    ap.add_argument("--png")
    ap.add_argument("--jobs", type=int, default=8)
    ap.add_argument("--views", default=",".join(VIEWS))
    ap.add_argument("--frames", action="store_true", help="print every frame-view with a slit")
    args = ap.parse_args()
    init(args.vskin)
    frames = json.loads(Path(args.poses).read_text())["frames"]
    rots = {k: view_basis(*VIEWS[k]) for k in args.views.split(",")}
    # One frame of every view fits the whole body with room for the arms to move.
    reach = np.linalg.norm(SKIN.centre - SKIN.centre.mean(0), axis=1).max() * 1.15
    mid = SKIN.centre.mean(0)
    size = (int(2 * reach / (SKIN.voxel * PIXEL)),) * 2
    jobs = [(fi, np.array(frames[fi]["m"], float).reshape(-1, 4, 4).transpose(0, 2, 1), rots, mid,
             reach, size) for fi in range(0, len(frames), args.step)]
    from multiprocessing import Pool
    with Pool(args.jobs, initializer=init, initargs=(args.vskin,)) as pool:
        results = pool.map(scan, jobs)
    worst, counts, bones = {}, {}, {}
    for fi, views in sorted(results, key=lambda r: r[0]):
        tag = frames[fi]["tag"]
        for name, g in views:
            counts.setdefault(tag, [0, 0])
            counts[tag][0] += 1
            counts[tag][1] += bool(g)
            for width, bone in g:
                bones.setdefault(bone, [0, 0.0])
                bones[bone][0] += 1
                bones[bone][1] = max(bones[bone][1], width)
            big = max((w for w, _ in g), default=0.0)
            if g and args.frames:
                print(f"  f{fi} {tag} {name}: " + ", ".join(f"{b} {w:.1f}" for w, b in g))
            if g and big >= worst.get(tag, (0.0,))[0]:
                worst[tag] = (big, fi, name, len(g))
    for tag, (_, fi, name, _) in worst.items() if args.png else []:
        rot = rots[name]
        m = np.array(frames[fi]["m"], float).reshape(-1, 4, 4).transpose(0, 2, 1)
        save_png(Path(args.png) / f"slits_{tag}.png", *SKIN.render(SKIN.pose(m), rot, (rot @ mid)[:2] - reach, size))
    total = 0
    for tag, (n, bad_n) in counts.items():
        total += bad_n
        w = worst.get(tag)
        desc = f"worst {w[0]:.1f} voxels across at frame {w[1]} ({w[2]}, {w[3]} slits)" if w else "none"
        print(f"{tag}: {bad_n}/{n} frame-views with a slit >= {MIN_VOXELS} voxel; {desc}")
    for bone, (n, w) in sorted(bones.items(), key=lambda kv: -kv[1][0]):
        print(f"  {bone}: {n} slits, widest {w:.1f} voxels")
    print(f"slit frame-views: {total}")


def save_png(path, hit, bad):
    from PIL import Image
    img = np.zeros(hit.shape + (3,), np.uint8)
    img[hit] = (150, 150, 150)
    img[ndimage.binary_dilation(bad >= 0, iterations=1)] = (255, 0, 0)
    ys, xs = np.nonzero(hit)
    img = img[::-1]
    if len(xs):
        img = img[hit.shape[0] - 1 - ys.max():hit.shape[0] - ys.min(), xs.min():xs.max() + 1]
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).resize((img.shape[1] * 2, img.shape[0] * 2), 0).save(path)


if __name__ == "__main__":
    main()
