"""Bone-ownership sheet and rig health numbers for rigged voxel kaiju (.kvox + .rig.json).

    python tools/capture/bone_sheet.py <out.png> <assets/kaiju/name> [<assets/kaiju/name> ...]

Draws each model front | side | top with every voxel coloured by its bone (the body's root bone
in slate), and prints per model: voxels, bones, and the faults that make a limb tear when it
moves: "fragments" (pieces of a limb chain cut off from the rest of that chain but touching another
part, 26-connected: they tear away when the limb moves; a piece touching nothing at all is a
loose mesh island and rides its chain whole),
"slate islands" (pieces of the root body cut off from it, e.g. stuck mid-tentacle) and
"unchained long arms" (root-body runs reaching further from the body's centre than its radius).
Pure numpy + Pillow.
"""
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SLATE = (60, 72, 96)
LINES = False  # --lines draws the bones over the voxels


def load(base):
    base = Path(base)
    raw = base.with_suffix(".kvox").read_bytes()
    count = struct.unpack_from("<I", raw, 14)[0]
    data = np.frombuffer(raw, dtype=np.dtype("<i2,<i2,<i2,u1,u1,u1,u1"), count=count, offset=18)
    pos = np.c_[data["f0"], data["f1"], data["f2"]].astype(int)
    rig = json.loads(base.with_suffix(".rig.json").read_text(encoding="utf-8"))
    return pos, data["f6"].astype(int), rig


def chain_of(name):
    """Chain a bone belongs to: tentacle3_2 -> tentacle3, leg_l1 -> leg_l, mantle0 -> mantle."""
    if "_" in name and name.split("_")[-1].isdigit():
        return name.rsplit("_", 1)[0]
    return name.rstrip("0123456789")


def components(pos):
    """Labels of 26-connected components of a voxel set."""
    index = {tuple(p): i for i, p in enumerate(pos)}
    label = np.full(len(pos), -1)
    steps = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if a or b or c]
    n = 0
    for i in range(len(pos)):
        if label[i] >= 0:
            continue
        label[i] = n
        stack = [i]
        while stack:
            j = stack.pop()
            p = pos[j]
            for a, b, c in steps:
                k = index.get((p[0] + a, p[1] + b, p[2] + c))
                if k is not None and label[k] < 0:
                    label[k] = n
                    stack.append(k)
        n += 1
    return label, n


def health(pos, bone, rig):
    names = [b["name"] for b in rig["bones"]]
    chains = np.array([chain_of(n) for n in names])
    owner_chain = chains[bone]
    root = chain_of(names[0])
    out = {"voxels": len(pos), "bones": len(names), "fragments": 0, "fragment_voxels": 0,
           "islands": 0, "island_voxels": 0, "slate_islands": 0, "slate_island_voxels": 0,
           "long_unchained": 0}
    for c in sorted(set(chains)):
        sel = np.where(owner_chain == c)[0]
        if len(sel) == 0:
            continue
        label, n = components(pos[sel])
        if n <= 1:
            continue
        sizes = np.bincount(label)
        extra = int(sizes.sum() - sizes.max())
        if c == root:
            out["slate_islands"] += n - 1
            out["slate_island_voxels"] += extra
            # A long run of body voxels far out from the centre is an arm with no chain.
        else:
            # A piece touching no other voxel is a separate mesh island riding its chain whole.
            occupied = {tuple(p) for p in pos}
            mine = {tuple(p) for p in pos[sel]}
            for k in range(n):
                if k == np.argmax(sizes):
                    continue
                piece = pos[sel][label == k]
                touches = any((p[0] + a, p[1] + b, p[2] + c) in occupied
                              and (p[0] + a, p[1] + b, p[2] + c) not in mine
                              for p in piece for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1))
                key = "fragment" if touches else "island"
                out[key + "s"] = out.get(key + "s", 0) + 1
                out[key + "_voxels"] = out.get(key + "_voxels", 0) + len(piece)
    if rig.get("type") == "radial":
        out["long_unchained"], out["longest_slate_run"], out["mantle_radius"] = slate_runs(pos, owner_chain == root)
    return out


def slate_runs(pos, body):
    """Runs of root-body voxels out past the mantle's radius, walked voxel to voxel from their
    inner end: how many are longer than that radius (arms with no chain), and the longest."""
    upper = pos[body & (pos[:, 1] > np.percentile(pos[:, 1], 55))]
    centre = upper[:, [0, 2]].mean(0)
    radius = float(np.median(np.linalg.norm(upper[:, [0, 2]] - centre, axis=1)) * 1.4)
    flat = np.linalg.norm(pos[:, [0, 2]] - centre, axis=1)
    sel = np.where(body & (flat > radius * 1.1))[0]
    if len(sel) == 0:
        return 0, 0, round(radius)
    label, n = components(pos[sel])
    index = {tuple(p): i for i, p in enumerate(pos[sel])}
    steps = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if a or b or c]
    long, longest = 0, 0
    for k in range(n):
        idx = np.where(label == k)[0]
        start = idx[np.argmin(flat[sel][idx])]
        dist = {start: 0}
        frontier = [start]
        while frontier:
            nxt = []
            for j in frontier:
                p = pos[sel][j]
                for a, b, c in steps:
                    q = index.get((p[0] + a, p[1] + b, p[2] + c))
                    if q is not None and q not in dist:
                        dist[q] = dist[j] + 1
                        nxt.append(q)
            frontier = nxt
        run = max(dist.values())
        longest = max(longest, run)
        long += run > radius
    return int(long), int(longest), round(radius)


def palette(n):
    rng = np.random.default_rng(3)
    cols = [SLATE]
    for _ in range(n - 1):
        h = rng.random()
        c = np.array([abs(h * 6 - 3) - 1, 2 - abs(h * 6 - 2), 2 - abs(h * 6 - 4)]).clip(0, 1)
        cols.append(tuple(int(x) for x in (c * 0.7 + 0.3) * 255))
    return cols


def view(pos, bone, cols, ax, depth, flip_depth, size, rig=None):
    """Orthographic view: nearest voxel along `depth` wins. With a rig, bones are drawn as lines."""
    u, v = pos[:, ax[0]], pos[:, ax[1]]
    d = pos[:, depth] * (-1 if flip_depth else 1)
    w, h = u.max() - u.min() + 1, v.max() - v.min() + 1
    img = np.zeros((h, w, 3), np.uint8)
    order = np.argsort(-d)  # far (high depth) first, near overwrites
    uu, vv = u[order] - u.min(), v.max() - v[order]
    img[vv, uu] = np.array(cols)[bone[order]]
    im = Image.fromarray(img)
    k = size / max(w, h)
    im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.NEAREST)
    if rig is not None:
        dr = ImageDraw.Draw(im)
        to = lambda p: ((p[ax[0]] - u.min()) * k, (v.max() - p[ax[1]]) * k)
        for b in rig["bones"]:
            dr.line([to(b["head"]), to(b["tail"])], fill=(255, 255, 255), width=1)
    return im


def main():
    global LINES
    args = [a for a in sys.argv[1:] if a != "--lines"]
    LINES = "--lines" in sys.argv
    out, bases = args[0], args[1:]
    size = 340
    sheet = Image.new("RGB", (size * 3 + 40, (size + 40) * len(bases)), (0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for row, base in enumerate(bases):
        pos, bone, rig = load(base)
        h = health(pos, bone, rig)
        print(Path(base).name, json.dumps(h))
        cols = palette(len(rig["bones"]))
        y = row * (size + 40) + 30
        # Game axes: x right, y up, -z forward. Front seen from -z, side from -x, top from +y.
        for col, (ax, depth, flip) in enumerate((((0, 1), 2, False), ((2, 1), 0, False), ((0, 2), 1, True))):
            im = view(pos, bone, cols, ax, depth, flip, size, rig if LINES else None)
            sheet.paste(im, (col * (size + 10) + 10, y))
        draw.text((10, y - 22), f"{Path(base).name}  bones {h['bones']}  fragments {h['fragments']} "
                  f"({h['fragment_voxels']} vox)  loose mesh islands {h['islands']}  slate islands {h['slate_islands']} "
                  f"({h['slate_island_voxels']} vox)  unchained long {h['long_unchained']} "
                  f"(longest {h.get('longest_slate_run', 0)} / radius {h.get('mantle_radius', 0)})",
                  fill=(230, 230, 230))
    sheet.save(out)


if __name__ == "__main__":
    main()
