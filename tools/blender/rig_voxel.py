"""Turns a rig-ready kaiju mesh (Tripo Smart Mesh GLB, T-pose, facing -Y) into the game's rigged voxel
model: colours it (dark hide, lighter belly, bone-coloured spikes and claws), fits a skeleton by
tracing the body's own limbs, voxelizes the surface and tags every voxel with its bone.

    blender -b --python tools/blender/rig_voxel.py -- <in.glb> <out_basename> <species> <height_vox>

Writes <out>.kvox (version 2, one pose; each voxel's flags byte is its bone index) and <out>.rig.json
(bones: name, parent, head, tail in voxel units with y up and -Z forward, plus "physics" chains).
Colours come from the model's base-colour texture when it has one (a Tripo textured export),
else from data/species.json. Pure Blender + numpy.
"""
import json
import struct
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]


# --- load and normalise ---------------------------------------------------------------------------

def base_image(mat):
    """The image feeding the material's Base Color, or None (Tripo textured exports have one)."""
    if mat is None or not mat.use_nodes:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            link = node.inputs["Base Color"].links
            if link and link[0].from_node.type == "TEX_IMAGE":
                return link[0].from_node.image
    return None


def load(path):
    """Vertices, normals, triangles, and per-triangle UVs plus texture (None when untextured)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    tris, verts_all, tri_uvs, tri_img, images = [], [], [], [], {}
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        mw = np.array(obj.matrix_world)
        v = np.array([x.co for x in mesh.vertices])
        v = (np.c_[v, np.ones(len(v))] @ mw.T)[:, :3]
        n = np.array([x.normal for x in mesh.vertices]) @ mw[:3, :3].T
        base = sum(len(x) for x in verts_all)
        verts_all.append((v, n))
        uv_layer = mesh.uv_layers.active.data if mesh.uv_layers.active else None
        for t in mesh.loop_triangles:
            tris.append([base + i for i in t.vertices])
            mat = obj.material_slots[t.material_index].material if obj.material_slots else None
            img = base_image(mat)
            if img is not None and img.size[0] > 0 and uv_layer is not None:
                if img.name not in images:
                    w, h = img.size
                    # Raw pixels of an 8-bit texture are display (sRGB) values: what .kvox stores.
                    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)
                    images[img.name] = px[:, :, :3]
                tri_img.append(img.name)
                tri_uvs.append([uv_layer[i].uv[:] for i in t.loops])
            else:
                tri_img.append(None)
                tri_uvs.append([(0, 0)] * 3)
        ev.to_mesh_clear()
    v = np.concatenate([a for a, _ in verts_all])
    n = np.concatenate([b for _, b in verts_all])
    n /= np.maximum(1e-9, np.linalg.norm(n, axis=1, keepdims=True))
    texture = (np.array(tri_uvs), tri_img, images) if images else None
    return v, n, np.array(tris), texture


def to_game(p):
    """Blender (x, y, z) Z-up facing -Y  ->  game (-x, z, y) Y-up facing -Z."""
    return np.c_[-p[..., 0], p[..., 2], p[..., 1]]


# --- colour ---------------------------------------------------------------------------------------

def neighbours(tris, count):
    nb = [set() for _ in range(count)]
    for a, b, c in tris:
        nb[a].update((b, c))
        nb[b].update((a, c))
        nb[c].update((a, b))
    return [np.fromiter(s, int) for s in nb]


def protrusion(v, nb, iters=12):
    """How far each vertex sticks out of a smoothed version of the body (spikes, claws, teeth)."""
    s = v.copy()
    for _ in range(iters):
        s = np.array([s[i] * 0.5 + s[nb[i]].mean(0) * 0.5 if len(nb[i]) else s[i] for i in range(len(s))])
    return np.linalg.norm(v - s, axis=1)


def vertex_colours(v, n, tris, colors, height):
    body = np.array(colors["body"])
    belly = np.array(colors["belly"])
    accent = np.array(colors["accent"])
    bone = np.array([0.72, 0.68, 0.58])
    nb = neighbours(tris, len(v))
    prot = protrusion(v, nb) / height
    z = (v[:, 2] - v[:, 2].min()) / height
    front = np.clip(-n[:, 1], 0, 1)  # faces -Y: the belly side
    col = np.tile(body, (len(v), 1))
    belly_w = np.clip((front - 0.35) * 2.5, 0, 1) * np.clip((0.8 - z) * 4, 0, 1)[:, None].ravel()
    col = col * (1 - belly_w[:, None]) + belly * belly_w[:, None]
    back_w = np.clip((n[:, 1] - 0.3) * 2, 0, 1)  # darker back
    col = col * (1 - back_w[:, None] * 0.5) + accent * back_w[:, None] * 0.5
    spike_w = np.clip((prot - 0.006) * 160, 0, 1) * 0.8
    col = col * (1 - spike_w[:, None]) + bone * spike_w[:, None]
    shade = 0.85 + 0.3 * (z[:, None])  # a little lighter up top
    return np.clip(col * shade, 0, 1)


# --- skeleton -------------------------------------------------------------------------------------

def trace(points, axis, start, end, segments, keep):
    """Joint positions along a body part: centroids of slices along `axis` from start to end."""
    sel = points[keep(points)]
    joints = []
    for t in np.linspace(start, end, segments + 1):
        band = sel[np.abs(sel[:, axis] - t) < abs(end - start) / (segments * 1.5)]
        if len(band) == 0:
            band = sel[np.argsort(np.abs(sel[:, axis] - t))[:30]]
        c = band.mean(0)
        c[axis] = t
        joints.append(c)
    return joints


def biped_skeleton(v, lo, hi):
    """Bones for an upright T-pose kaiju: tail traced behind, legs, spine, neck, head, arms."""
    H = hi[2] - lo[2]
    W = hi[0] - lo[0]
    z = lambda f: lo[2] + f * H
    bones = []

    def chain(name, joints, parent, physics=False):
        nonlocal bones
        prev = parent
        for i in range(len(joints) - 1):
            bname = f"{name}{i}" if len(joints) > 2 else name
            bones.append({"name": bname, "parent": prev, "head": joints[i], "tail": joints[i + 1],
                          "physics": physics})
            prev = bname
        return prev

    body = lambda p: (np.abs(p[:, 0]) < W * 0.14) & (p[:, 1] < lo[1] + (hi[1] - lo[1]) * 0.45)
    pelvis = v[body(v) & (np.abs(v[:, 2] - z(0.4)) < H * 0.05)].mean(0)
    pelvis[0] = 0.0
    spine = trace(v, 2, z(0.4), z(0.8), 3, body)
    spine[0] = pelvis
    chain("spine", spine, None)
    head = trace(v, 2, z(0.8), hi[2], 2, lambda p: np.abs(p[:, 0]) < W * 0.12)
    head[-1] = v[(v[:, 2] > z(0.85))][np.argmin(v[(v[:, 2] > z(0.85))][:, 1])]  # snout tip
    chain("head", head, "spine2")
    # Arm height: where the upper body is widest (T-pose or arms raised alike).
    fracs = np.linspace(0.5, 0.95, 19)
    widths = [np.ptp(v[np.abs(v[:, 2] - z(f)) < H * 0.03][:, 0]) if np.any(np.abs(v[:, 2] - z(f)) < H * 0.03) else 0 for f in fracs]
    arm_f = float(fracs[int(np.argmax(widths))])
    for side, sx in (("l", 1), ("r", -1)):
        arm = lambda p, sx=sx: (p[:, 0] * sx > W * 0.12) & (np.abs(p[:, 2] - z(arm_f)) < H * 0.15)
        tip = hi[0] if sx > 0 else lo[0]
        joints = trace(v, 0, sx * W * 0.12, tip * 0.97, 3, arm)
        chain(f"arm_{side}", joints, "spine2", physics=False)
        leg = lambda p, sx=sx: (p[:, 0] * sx > W * 0.02) & (p[:, 2] < z(0.42)) & (p[:, 1] < lo[1] + (hi[1] - lo[1]) * 0.45)
        joints = trace(v, 2, z(0.4), lo[2], 3, leg)
        chain(f"leg_{side}", joints, "spine0")
    behind = lambda p: (p[:, 1] > lo[1] + (hi[1] - lo[1]) * 0.42) & (p[:, 2] < z(0.45))
    tail = trace(v, 1, lo[1] + (hi[1] - lo[1]) * 0.42, hi[1] * 0.98, 8, behind)
    tail.insert(0, pelvis)
    chain("tail", tail, "spine0", physics=True)
    return bones


JAW_CLOSE_MAX = 1.0


def split_jaw(points, owner, bones, cell, rgb):
    """Cuts the lower jaw off the skull (a biped's head1) into its own bone, "jaw", hinged at the
    back of the mouth. An open sculpted mouth shows its red interior: the mouth line runs through
    the middle of it, and "close" is how far the jaw must turn up (radians, about its hinge) to
    shut it. A closed mouth (no interior) is cut at the emptiest band across the front of the
    skull. Returns the new owners (bones gains the jaw), or the old ones if no mouth is found."""
    names = [b["name"] for b in bones]
    if "head1" not in names:
        return owner
    hi = names.index("head1")
    h, t = np.array(bones[hi]["head"]), np.array(bones[hi]["tail"])
    L = np.linalg.norm(t - h)
    a = (t - h) / L
    up = np.array([0.0, 0.0, 1.0]) - a * a[2]
    up /= np.linalg.norm(up)
    idx = np.where(owner == hi)[0]
    rel = points[idx] - h
    s_along, u = rel @ a / L, rel @ up
    front = s_along > 0.45
    if front.sum() < 50:
        return owner
    c = rgb[idx]
    inside = front & (c[:, 0] > c[:, 1] * 1.35) & (c[:, 0] > c[:, 2] * 1.35)
    hinge_s = 0.3
    if inside.sum() >= 12:
        lo_u, hi_u = np.percentile(u[inside], [10, 90])
        cut = (lo_u + hi_u) / 2
        hinge_s = max(0.15, float(np.percentile(s_along[inside], 5)) - 0.05)
    else:
        bins = np.arange(u[front].min(), u[front].max() + cell, cell)
        counts, _ = np.histogram(u[front], bins)
        counts = np.convolve(counts, np.ones(3) / 3, mode="same")
        lo_i, hi_i = int(len(counts) * 0.2), int(len(counts) * 0.75)
        if hi_i <= lo_i:
            return owner
        k = lo_i + int(np.argmin(counts[lo_i:hi_i]))
        cut = (bins[k] + bins[k + 1]) / 2
        lo_u = hi_u = cut
    jaw = (s_along > hinge_s) & (u < cut)
    if jaw.sum() < 30:
        return owner
    tip_s = s_along[jaw].max()
    reach = max(cell, (tip_s - hinge_s) * L)
    # Tongue and throat sit inside the gap too: at most JAW_CLOSE_MAX shuts the snarl.
    close = min(JAW_CLOSE_MAX, float(np.arctan2(max(0.0, hi_u - lo_u), reach)))
    hinge = h + a * hinge_s * L + up * cut
    jaw_tip = points[idx[jaw]][np.argmax(s_along[jaw])]
    bones.append({"name": "jaw", "parent": "head1", "head": hinge, "tail": jaw_tip, "physics": False,
                  "close": round(close, 3)})
    out = owner.copy()
    out[idx[jaw]] = len(bones) - 1
    print(f"jaw: {jaw.sum()} voxels, mouth gap closes by {np.degrees(close):.1f} deg")
    return out


def close_jaw(keys, values, owner, bones, scale, origin, shut=1.0):
    """Bakes the shut jaw into the voxels: the jaw's cells turn up about its hinge by its "close"
    angle and land in new cells, and "close" becomes 0. At rest the mouth is then shut (its red
    inside folds away, a hairline at the lips) and nothing turns while it walks: a jaw turned
    shut every frame opened a see-through gap under the chin. Only a roar opens it. shut < 1 bakes
    the jaw only that share of the way (a resting snarl, teeth and pink showing: the director's
    pick for the adult) and marks it "snarl", so the game shows its true colours at rest."""
    names = [b["name"] for b in bones]
    if "jaw" not in names:
        return keys, values, owner
    ji = names.index("jaw")
    jaw = bones[ji]
    angle = float(jaw.get("close", 0.0)) * shut
    if angle <= 0.0:
        return keys, values, owner
    hinge, tip = np.array(jaw["head"]), np.array(jaw["tail"])
    fwd = (tip - hinge) / np.linalg.norm(tip - hinge)
    up = np.array([0.0, 0.0, 1.0]) - fwd * fwd[2]
    up /= np.linalg.norm(up)
    def turn(p, by):
        rel = p - hinge
        s, v = rel @ fwd, rel @ up
        rest = rel - np.outer(s, fwd) - np.outer(v, up)
        c, sn = np.cos(by), np.sin(by)
        return hinge + rest + np.outer(s * c - v * sn, fwd) + np.outer(s * sn + v * c, up)
    # Inverse mapping (no holes): every cell around the turned jaw looks back at where it came from.
    on_jaw = owner == ji
    src = {tuple(k): i for i, k in zip(np.where(on_jaw)[0], keys[on_jaw])}
    taken = {tuple(k) for k in keys[~on_jaw]}
    ends = np.floor((turn((keys[on_jaw] + 0.5) / scale + origin, angle) - origin) * scale)
    lo, hi = ends.min(0).astype(int) - 2, ends.max(0).astype(int) + 3
    grid = np.stack(np.meshgrid(*[np.arange(l, h) for l, h in zip(lo, hi)], indexing="ij"), -1).reshape(-1, 3)
    back = np.floor((turn((grid + 0.5) / scale + origin, -angle) - origin) * scale).astype(int)
    keep = np.where(~on_jaw)[0]
    new_keys, new_values, new_owner = list(keys[keep]), [values[i] for i in keep], list(owner[keep])
    landed = 0
    for k, b in zip(map(tuple, grid), map(tuple, back)):
        if b in src and k not in taken:  # the skull keeps its own cells
            new_keys.append(np.array(k)); new_values.append(values[src[b]]); new_owner.append(ji)
            landed += 1
    jaw["tail"] = turn(tip[None, :], angle)[0]
    jaw["close"] = 0.0
    if shut < 1.0:
        jaw["snarl"] = True
    print(f"jaw baked shut: turned {np.degrees(angle):.1f} deg, {landed} cells")
    return np.array(new_keys), new_values, np.array(new_owner)


BLEMISH_WARM = 8 / 255  # how much warmer than green and blue (0..1) reads as a blemish
BLEMISH_REACH = 2  # cells


def clean_blemishes(keys, values, owner, bones):
    """Texture blemishes on the torso (warm pink spots that read as nipples on the adult):
    a voxel on a spine bone whose colour is warm against the body (red above green and blue by
    BLEMISH_WARM) takes the median colour of its non-warm neighbours within BLEMISH_REACH cells.
    Mouth, eyes and every other bone are left alone."""
    names = [b["name"] for b in bones]
    torso = {i for i, n in enumerate(names) if n.startswith("spine")}
    rgb = np.array([[r / c, g / c, b / c] for r, g, b, c in values])
    warm = (rgb[:, 0] > rgb[:, 1] + BLEMISH_WARM) & (rgb[:, 0] > rgb[:, 2] + BLEMISH_WARM)
    index = {tuple(k): i for i, k in enumerate(keys)}
    span = range(-BLEMISH_REACH, BLEMISH_REACH + 1)
    fixed = 0
    out = list(values)
    for i in np.where(warm & np.isin(owner, list(torso)))[0]:
        k = keys[i]
        near = [index.get((k[0] + a, k[1] + b, k[2] + c)) for a in span for b in span for c in span]
        calm = [j for j in near if j is not None and not warm[j]]
        if calm:
            m = np.median(rgb[calm], axis=0)
            out[i] = [m[0], m[1], m[2], 1]
            fixed += 1
    print(f"torso blemishes cleaned: {fixed}")
    return out


def adopt_orphans(keys, owner):
    """A voxel with no neighbour on its own bone would float free when that bone moves: it joins
    the bone most of its neighbours are on."""
    index = {tuple(k): i for i, k in enumerate(keys)}
    out = owner.copy()
    steps = [(dx, dy, dz) for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1) if dx or dy or dz]
    moved = 0
    for i, k in enumerate(keys):
        around = [owner[j] for j in (index.get((k[0] + a, k[1] + b, k[2] + c)) for a, b, c in steps) if j is not None]
        if around and owner[i] not in around:
            out[i] = max(set(around), key=around.count)
            moved += 1
    print(f"orphans adopted: {moved}")
    return out


def nearest_bone(points, bones, side_of):
    """Index of the bone whose segment is nearest each point (limbs stay on their own side)."""
    best = np.full(len(points), -1)
    best_d = np.full(len(points), np.inf)
    for i, b in enumerate(bones):
        a, c = np.array(b["head"]), np.array(b["tail"])
        ab = c - a
        t = np.clip(((points - a) @ ab) / max(1e-9, ab @ ab), 0, 1)
        d = np.linalg.norm(points - (a + t[:, None] * ab), axis=1)
        s = side_of(b["name"])
        if s != 0:
            d = np.where(np.sign(points[:, 0]) == s, d, d + 1e3)
        better = d < best_d
        best[better], best_d[better] = i, d[better]
    return best


PLATE_MARGIN = 1.5
PLATE_ROOT = 0.35


def reclaim_plates(points, owner, bones):
    """Shoulder plates and dorsal spikes sit beside the upper arm but belong to the torso: an
    upper-arm voxel near the shoulder (the inner PLATE_ROOT of the bone) and farther from it than
    the forearm is thick (times PLATE_MARGIN), or above it by that thickness, goes to the nearest spine bone, so the plates ride
    the chest instead of swinging with the arm. Bumps out along the arm stay on it: left on the
    chest they would float where the sculpted arm was."""
    names = [b["name"] for b in bones]
    seg = lambda i, p: _seg_dist(p, bones[i])
    body = [i for i, n in enumerate(names) if n.startswith("spine")]  # never the head: it turns
    out = owner.copy()
    moved = 0
    for side in ("l", "r"):
        if f"arm_{side}0" not in names or f"arm_{side}1" not in names:
            continue
        upper, fore = names.index(f"arm_{side}0"), names.index(f"arm_{side}1")
        radius = np.median(seg(fore, points[owner == fore])) * PLATE_MARGIN
        idx = np.where(owner == upper)[0]
        a, c = np.array(bones[upper]["head"]), np.array(bones[upper]["tail"])
        along = ((points[idx] - a) @ (c - a)) / max(1e-9, (c - a) @ (c - a))
        # Above the shoulder counts too: the arm lowers, and its top would rise off the body.
        axis_z = a[2] + np.clip(along, 0, 1) * (c[2] - a[2])
        above = points[idx][:, 2] - axis_z > radius / PLATE_MARGIN
        # Inboard of the shoulder joint is chest: lowering the arm would swing it up and away.
        inboard = along < 0.0
        far = idx[(((seg(upper, points[idx]) > radius) | above) & (along < PLATE_ROOT)) | inboard]
        if len(far) == 0:
            continue
        dists = np.stack([seg(i, points[far]) for i in body])
        out[far] = np.array(body)[np.argmin(dists, axis=0)]
        moved += len(far)
    print(f"plates reclaimed: {moved}")
    return out


def _seg_dist(points, b):
    a, c = np.array(b["head"]), np.array(b["tail"])
    ab = c - a
    t = np.clip(((points - a) @ ab) / max(1e-9, ab @ ab), 0, 1)
    return np.linalg.norm(points - (a + t[:, None] * ab), axis=1)


# --- voxelize -------------------------------------------------------------------------------------

def surface_voxels(v, tris, col, scale, origin, texture=None):
    """Voxel cells sampled over every triangle; colours from the texture when there is one,
    else interpolated from the vertex colours."""
    cells = {}
    for t, (a, b, c) in enumerate(tris):
        q = (v[[a, b, c]] - origin) * scale
        edge = max(np.linalg.norm(q[1] - q[0]), np.linalg.norm(q[2] - q[1]), np.linalg.norm(q[0] - q[2]))
        n = max(2, int(edge * 2) + 1)
        u, w = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
        u, w = u.ravel(), w.ravel()
        k = u + w <= 1
        u, w = u[k], w[k]
        bary = np.c_[1 - u - w, u, w]
        pts = bary @ q
        if texture is not None and texture[1][t] is not None:
            px = texture[2][texture[1][t]]
            ph, pw = px.shape[:2]
            uvs = bary @ texture[0][t]
            ix = np.clip((uvs[:, 0] % 1.0) * (pw - 1), 0, pw - 1).astype(int)
            iy = np.clip((uvs[:, 1] % 1.0) * (ph - 1), 0, ph - 1).astype(int)
            cs = px[iy, ix]
        else:
            cs = bary @ col[[a, b, c]]
        for key, cc in zip(map(tuple, np.floor(pts).astype(int)), cs):
            acc = cells.get(key)
            if acc is None:
                cells[key] = [cc[0], cc[1], cc[2], 1]
            else:
                acc[0] += cc[0]; acc[1] += cc[1]; acc[2] += cc[2]; acc[3] += 1
    return cells


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, out, species, height = args[0], Path(args[1]), args[2], int(args[3])
    jaw_shut = float(args[4]) if len(args) > 4 else 1.0  # share of the snarl baked shut
    defs = json.loads((ROOT / "data/species.json").read_text(encoding="utf-8"))["species"]
    hexes = next(d for d in defs if d["id"] == species)["colors"]
    colors = {k: [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] for k, h in hexes.items()}
    v, n, tris, texture = load(src)
    lo, hi = v.min(0), v.max(0)
    H = hi[2] - lo[2]
    col = vertex_colours(v, n, tris, colors, H)
    bones = biped_skeleton(v, lo, hi)
    scale = (height - 1) / H
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    cells = surface_voxels(v, tris, col, scale, origin, texture)
    print("colours from", "texture" if texture is not None else "species palette")
    keys = np.array(list(cells.keys()))
    centres_bl = (keys + 0.5) / scale + origin  # back to Blender space for bone tests
    side = lambda name: 1 if "_l" in name else (-1 if "_r" in name else 0)
    owner = nearest_bone(centres_bl, bones, side)
    owner = reclaim_plates(centres_bl, owner, bones)
    rgb =np.array([[r / cnt, gr / cnt, b / cnt] for r, gr, b, cnt in cells.values()])
    owner = split_jaw(centres_bl, owner, bones, 1.0 / scale, rgb)
    values = list(cells.values())
    keys, values, owner = close_jaw(keys, values, owner, bones, scale, origin, jaw_shut)
    owner = adopt_orphans(keys, owner)
    values = clean_blemishes(keys, values, owner, bones)
    # Write voxels (game axes) with their bone index in the flags byte.
    gk = to_game(keys.astype(float))
    gk[:, 0] -= 1  # keep integer cells after the x flip
    with open(out.with_suffix(".kvox"), "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, height))
        f.write(struct.pack("<I", len(values)))
        for g, (r, gr, b, cnt), bone in zip(gk.astype(int), values, owner):
            # Species colours are already display (sRGB) values: no gamma here.
            rgb = [int(max(0, min(255, round(x / cnt * 255)))) for x in (r, gr, b)]
            f.write(struct.pack("<hhhBBBB", g[0], g[1], g[2], *rgb, int(bone)))
    rig = {"height": height, "bones": []}
    for b in bones:
        head = to_game(((np.array(b["head"]) - origin) * scale)[None])[0]
        tail = to_game(((np.array(b["tail"]) - origin) * scale)[None])[0]
        entry = {"name": b["name"], "parent": b["parent"], "head": head.round(2).tolist(),
                 "tail": tail.round(2).tolist(), "physics": b["physics"]}
        if "close" in b:
            entry["close"] = b["close"]
        if b.get("snarl"):
            entry["snarl"] = True
        rig["bones"].append(entry)
    out.with_suffix(".rig.json").write_text(json.dumps(rig, indent=1), encoding="utf-8")
    counts = np.bincount(owner, minlength=len(bones))
    print(f"rigged {src}: {len(values)} voxels, {len(bones)} bones; voxels per bone min {counts.min()}")


main()
