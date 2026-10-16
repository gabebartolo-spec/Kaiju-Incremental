"""Turns a rig-ready kaiju mesh (Tripo Smart Mesh GLB, T-pose, facing -Y) into the game's rigged voxel
model: colours it (dark hide, lighter belly, bone-coloured spikes and claws), fits a skeleton by
tracing the body's own limbs, voxelizes the surface and tags every voxel with its bone.

    blender -b --python tools/blender/rig_voxel.py -- <in.glb> <out_basename> <species> <height_vox>

Writes <out>.kvox (version 2, one pose; each voxel's flags byte is its bone index) and <out>.rig.json
(type "biped", "hexapod" or "radial"; bones: name, parent, head, tail in voxel units with y up and -Z forward,
plus "physics" chains). The insectoid gets the hexapod skeleton (D-022 mantis), the cephalopod a
radial one (mantle + 8 tentacle chains), the reptilian a biped.
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


def geodesic(v, tris, sources):
    """Distance over the surface from the nearest source vertex, and each vertex's predecessor.
    Vertices at the same position are welded first: a textured export splits them at UV seams,
    which would cut the surface into islands no walk can cross."""
    import heapq
    _, weld = np.unique(np.round(v, 5), axis=0, return_inverse=True)
    weld = weld.ravel()
    first = {}
    for i, w in enumerate(weld):
        first.setdefault(int(w), i)
    rep = np.array([first[int(w)] for w in weld])
    tris = rep[np.asarray(tris)]
    adj = [[] for _ in range(len(v))]
    for a, b, c in tris:
        for p, q in ((a, b), (b, c), (c, a)):
            d = float(np.linalg.norm(v[p] - v[q]))
            adj[p].append((q, d))
            adj[q].append((p, d))
    dist = np.full(len(v), np.inf)
    prev = np.full(len(v), -1)
    heap = []
    for s in sources:
        dist[s] = 0.0
        heap.append((0.0, int(s)))
    heapq.heapify(heap)
    while heap:
        d, x = heapq.heappop(heap)
        if d > dist[x]:
            continue
        for y, w in adj[x]:
            if d + w < dist[y]:
                dist[y] = d + w
                prev[y] = x
                heapq.heappush(heap, (d + w, y))
    return dist[rep], prev[rep]


def path_to_core(v, prev, tip):
    """Vertex positions from a limb tip back along the surface to the body's midline."""
    out = [tip]
    while prev[out[-1]] >= 0:
        out.append(prev[out[-1]])
    return v[out]


def at_arc(path, frac):
    """Point a fraction of the way along a polyline (by length)."""
    seg = np.linalg.norm(np.diff(path, axis=0), axis=1)
    acc = np.r_[0, np.cumsum(seg)]
    target = acc[-1] * frac
    i = min(int(np.searchsorted(acc, target)), len(path) - 1)
    return path[i]


def hexapod_skeleton(v, tris, lo, hi):
    """Bones for a mantis-like insect: thorax and head on the midline, an abdomen, two raptorial
    arms, four walking legs and two antennae (physics). Limbs are found by walking over the
    surface from each tip (foot, claw, antenna tip) back to the body's midline."""
    H = hi[2] - lo[2]
    W = hi[0] - lo[0]
    z = lambda f: lo[2] + f * H
    core = np.where(np.abs(v[:, 0]) < W * 0.03)[0]
    dist, prev = geodesic(v, tris, core)
    reach = np.where(np.isfinite(dist), dist, -1)
    bones = []

    def chain(name, joints, parent, physics=False):
        prev_name = parent
        for i in range(len(joints) - 1):
            bname = f"{name}{i}"
            bones.append({"name": bname, "parent": prev_name, "head": np.array(joints[i]),
                          "tail": np.array(joints[i + 1]), "physics": physics})
            prev_name = bname
        return prev_name

    # Feet: the four lowest clusters away from the midline, one per quadrant.
    feet = {}
    low = np.where((v[:, 2] < z(0.05)) & (np.abs(v[:, 0]) > W * 0.12))[0]
    for side, sx in (("l", 1), ("r", -1)):
        for end, sy in (("leg", -1), ("hind", 1)):  # -Y is forward
            mask = low[(np.sign(v[low, 0]) == sx) & (np.sign(v[low, 1] - np.median(v[low, 1])) == sy)]
            if len(mask) == 0:
                raise SystemExit(f"no foot found for {end}_{side}")
            feet[(end, side)] = mask[np.argmax(reach[mask])]
    hips = {}
    for key, tip in feet.items():
        path = path_to_core(v, prev, tip)
        hips[key] = at_arc(path, 0.8)
        feet[key] = (path[0], at_arc(path, 0.12), at_arc(path, 0.5))
    waist = np.mean([h for h in hips.values()], axis=0)
    waist[0] = 0.0
    # Head: the top of the midline below the antennae; neck where it narrows below it.
    upper_core = v[(np.abs(v[:, 0]) < W * 0.12) & (v[:, 2] > z(0.6))]
    # The head's top is the highest slab of the midline with real bulk (antennae are thin).
    bins = np.arange(z(0.6), hi[2] + H * 0.02, H * 0.02)
    counts, _ = np.histogram(upper_core[:, 2], bins)
    solid = np.where(counts >= counts.max() * 0.15)[0]
    top_z = bins[solid[-1] + 1] if len(solid) else hi[2]
    upper_core = upper_core[upper_core[:, 2] <= top_z]
    head_top = upper_core[np.argmax(upper_core[:, 2])] if len(upper_core) else hi
    head_pts = upper_core[upper_core[:, 2] > head_top[2] - H * 0.1]
    head_c = head_pts.mean(0)
    mouth = head_pts[np.argmin(head_pts[:, 1])]
    neck = upper_core[np.abs(upper_core[:, 2] - (head_top[2] - H * 0.14)) < H * 0.02].mean(0)
    for p in (head_c, neck):
        p[0] = 0.0
    mid = (waist + neck) / 2
    HEAD_ZONE.update({"neck_z": neck[2], "centre": head_c, "radius": H * 0.14})
    chain("thorax", [waist, mid, neck], None)
    bones.append({"name": "head0", "parent": "thorax1", "head": neck, "tail": mouth, "physics": False})
    # Abdomen: the furthest midline point behind and below the waist.
    back = np.where((np.abs(v[:, 0]) < W * 0.1) & (v[:, 2] < waist[2]) & (v[:, 1] > waist[1]))[0]
    tip = v[back[np.argmax(np.linalg.norm(v[back] - waist, axis=1))]] if len(back) else waist + [0, H * 0.3, -H * 0.2]
    abdomen = [waist + (tip - waist) * f for f in (0.0, 0.35, 0.7, 1.0)]
    chain("abdomen", abdomen, "thorax0")
    for (end, side), (foot, ankle, knee) in feet.items():
        chain(f"{end}_{side}", [hips[(end, side)], knee, ankle, foot], "thorax0")
    for side, sx in (("l", 1), ("r", -1)):
        # Raptorial arm: the furthest surface point on this side of the upper body (the claw tip).
        cand = np.where((np.sign(v[:, 0]) == sx) & (v[:, 2] > z(0.35)) & (v[:, 2] < head_c[2])
                        & (np.abs(v[:, 0]) > W * 0.1))[0]
        claw = cand[np.argmax(reach[cand])]
        path = path_to_core(v, prev, claw)
        k = np.argmax(path[: int(len(path) * 0.8), 2])
        elbow = path[k]
        shoulder = at_arc(path, 0.88)
        wrist = at_arc(path[:k + 1], 0.45)
        chain(f"arm_{side}", [shoulder, elbow, wrist, path[0]], "thorax1")
        # Antenna: the highest point on this side above the head.
        top = np.where((np.sign(v[:, 0]) == sx) & (v[:, 2] > head_top[2] - H * 0.05))[0]
        if len(top) == 0:
            continue
        a_tip = top[np.argmax(v[top, 2])]
        if np.isfinite(dist[a_tip]):
            path = path_to_core(v, prev, a_tip)
            near = np.where(np.linalg.norm(path - head_c, axis=1) < H * 0.06)[0]
            base_i = int(near[0]) if len(near) else len(path) // 2
            ant = path[: base_i + 1]
            joints = [at_arc(ant, f) for f in (1.0, 0.66, 0.33, 0.0)]
        else:
            # A separate mesh island: from its point nearest the head straight out to its tip.
            island = np.where(~np.isfinite(dist) & (np.sign(v[:, 0]) == sx))[0]
            base = v[island[np.argmin(np.linalg.norm(v[island] - head_c, axis=1))]]
            joints = [base + (v[a_tip] - base) * f for f in (0.0, 0.33, 0.66, 1.0)]
        chain(f"antenna_{side}", joints, "head0", physics=True)
    for b in bones:
        b["head"], b["tail"] = b["head"].tolist(), b["tail"].tolist()
    return bones


# Radial bodies (shares of the body's width): how wide a found tentacle claims the surface (so
# the next tip is a different tentacle), how thick a tentacle's voxels may be around its chain,
# and how long (share of the longest) a tip must reach to count as a tentacle.
TENTACLE_CLAIM = 0.09
TENTACLE_THICK = (0.09, 0.04)  # at the root, at the tip
TENTACLE_MIN_REACH = 0.5
# How far (times its root thickness) from its chain a tentacle may claim voxels.
TENTACLE_REACH = 1.3
# Mantle seeds: within this share of the mantle's radius. A run of mantle voxels with fewer
# voxels than this per step along it is an arm, not the head's shell.
MANTLE_SEED = 0.6
MANTLE_FLOOR = 0.55
ARM_PER_STEP = 30


def radial_skeleton(v, tris, lo, hi, segments=6, max_arms=16):
    """Bones for an octopus- or hydra-like body: a mantle on the midline and one physics chain per
    tentacle, however many the sculpt has. Tentacles are found one at a time: the surface point
    furthest (over the surface) from the body is a tip; its path back to the body is that
    tentacle, and everything near the path is claimed so the next tip is a different tentacle.
    It stops when the furthest unclaimed point is short of a tentacle's reach."""
    H = hi[2] - lo[2]
    W = max(hi[0] - lo[0], hi[1] - lo[1])
    # The body's centre is under its mantle/head (the upper body), not the bounding box's centre.
    top = v[v[:, 2] > lo[2] + H * 0.55]
    centre = top[:, :2].mean(0) if len(top) else np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2])
    # The core is under the mantle, low: a path from a tip ends where its arm meets the body,
    # never climbing the face to the crown.
    core = np.where((np.linalg.norm(v[:, :2] - centre, axis=1) < W * 0.06) & (v[:, 2] < lo[2] + H * 0.35))[0]
    if len(core) < 3:
        core = np.where(np.linalg.norm(v[:, :2] - centre, axis=1) < W * 0.06)[0]
    dist, prev = geodesic(v, tris, core)
    reach = np.where(np.isfinite(dist), dist, -1.0)
    body = v[core]
    base = np.array([centre[0], centre[1], body[:, 2].min() + H * 0.05])
    crown = np.array([centre[0], centre[1], hi[2]])
    bones = [{"name": "mantle0", "parent": None, "head": base, "tail": crown, "physics": False}]
    free = reach.copy()
    # A tip is out past the mantle (a big round head has far-away points of its own).
    flat = np.linalg.norm(v[:, :2] - centre, axis=1)
    upper = flat[v[:, 2] > lo[2] + H * 0.55]
    # The mantle dominates the upper body (raised tentacles are a minority): its median radius.
    mantle_r = np.median(upper) * 1.4 if len(upper) else W * 0.1
    free[flat < mantle_r * 1.05] = -1.0
    # Near the head, tips hang low (a big head's crown is not one); out wide, a raised arch may be.
    free[(v[:, 2] > lo[2] + H * 0.6) & (flat < mantle_r * 1.6)] = -1.0
    # A tip is thin: little surface around it (a head's shell is broad).
    cell = (v / (W * 0.04)).astype(int)
    _, inverse, counts = np.unique(cell, axis=0, return_inverse=True, return_counts=True)
    crowd = counts[inverse.ravel()]
    free[crowd > np.percentile(crowd, 60)] = -1.0
    MANTLE_ZONE.update({"width": W, "centre": centre, "radius": mantle_r, "floor": lo[2] + H * MANTLE_FLOOR})
    longest = free.max()
    radius = W * TENTACLE_CLAIM
    found = []  # outer path points of every tentacle so far
    count = 0
    for _ in range(max_arms * 3):
        if count >= max_arms:
            break
        tip = int(np.argmax(free))
        if free[tip] < longest * TENTACLE_MIN_REACH:
            break
        path = path_to_core(v, prev, tip)
        # Claim this tentacle: every vertex near its outer path, so the next tip is another one.
        outer = path[: max(2, int(len(path) * 0.9))]
        for chunk in np.array_split(outer, max(1, len(outer) // 50)):
            near = np.min(np.linalg.norm(v[:, None, :] - chunk[None, :, :], axis=2), axis=1) < radius
            free[near] = -1.0
        # A tip whose path mostly runs alongside a tentacle already found is that tentacle again.
        span = path[: max(2, int(len(path) * 0.6))]
        if found:
            seen = np.concatenate(found)
            close = np.min(np.linalg.norm(span[:, None, :] - seen[None, :, :], axis=2), axis=1)
            if np.mean(close < radius * 1.5) > 0.3:
                continue
        found.append(outer[:: max(1, len(outer) // 40)])
        joints = [at_arc(path, f) for f in np.linspace(0.92, 0.0, segments + 1)]
        # A "tentacle" lying high from root to tip is a ridge on the mantle's own shell.
        if joints[0][2] > lo[2] + H * 0.3 and joints[-1][2] > lo[2] + H * 0.3:
            continue
        parent = "mantle0"
        for j in range(segments):
            name = f"tentacle{count}_{j}"
            bones.append({"name": name, "parent": parent, "head": joints[j], "tail": joints[j + 1],
                          "physics": True})
            parent = name
        count += 1
    print(f"radial: {(len(bones) - 1) // segments} tentacles")
    for b in bones:
        b["head"], b["tail"] = np.asarray(b["head"]).tolist(), np.asarray(b["tail"]).tolist()
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


# Where the hexapod's head is (set by hexapod_skeleton): voxels above the neck near the head's
# centre belong to the head whatever bone is nearest, so the head turns as one piece.
HEAD_ZONE = {}
# Where a radial body's mantle is (set by radial_skeleton): voxels above tentacle height within
# its radius stay on the mantle, so a big head never flaps about on a tentacle.
MANTLE_ZONE = {}

# Limb roots sit against the body; their distance is stretched so body voxels stay on the body.
ROOT_PENALTY = {"leg": 2.0, "hind": 2.0, "arm": 1.4, "antenna": 4.0, "tentacle": 2.0}


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


def neighbour_table(keys):
    """(N, 26) index of each voxel's neighbours (-1 where empty), from a dense grid."""
    lo = keys.min(0) - 1
    k = keys - lo
    grid = np.full(tuple(k.max(0) + 2), -1, dtype=np.int64)
    grid[k[:, 0], k[:, 1], k[:, 2]] = np.arange(len(keys))
    steps = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1) if a or b or c]
    return np.stack([grid[k[:, 0] + a, k[:, 1] + b, k[:, 2] + c] for a, b, c in steps], axis=1)


def grow(label, nb, allow=None):
    """Fills unlabelled voxels (-1) outward from the labelled ones, one shell at a time (each
    takes the commonest label among its labelled neighbours): a Voronoi split over the body, so
    every region stays joined to its seeds. allow[i, c] (optional) says voxel i may take label c."""
    label = label.copy()
    while True:
        todo = np.where(label < 0)[0]
        if len(todo) == 0:
            return label
        around = np.where(nb[todo] >= 0, label[np.maximum(nb[todo], 0)], -1)
        if allow is not None:
            ok = allow[todo[:, None], np.maximum(around, 0)]
            around = np.where(ok, around, -1)
        has = (around >= 0).any(1)
        if not has.any():
            return label  # islands with no seed keep -1
        rows = todo[has]
        label[rows] = majority(around[has])


def majority(around):
    """Commonest non-negative value per row (rows must have one)."""
    top = around.max() + 1
    counts = np.zeros((len(around), top), dtype=np.int32)
    for j in range(around.shape[1]):
        ok = around[:, j] >= 0
        np.add.at(counts, (np.where(ok)[0], around[ok, j]), 1)
    return counts.argmax(1)


def pieces(label, nb):
    """Connected-component id per voxel (26-connected, same label only)."""
    comp = np.arange(len(label))
    same = (nb >= 0) & (label[np.maximum(nb, 0)] == label[:, None])
    while True:
        around = np.where(same, comp[np.maximum(nb, 0)], len(label))
        new = np.minimum(comp, around.min(1))
        new = new[new]  # pointer jumping speeds it up
        if np.array_equal(new, comp):
            return comp
        comp = new


def join_fragments(label, nb, keep=()):
    """Every piece of a label that is not its largest piece is cut loose when that label moves:
    it joins the label it touches most. Repeats until each label is one piece (a piece touching
    nothing else, a separate mesh island, stays). Labels in `keep` may be in several pieces."""
    for _ in range(20):
        comp = pieces(label, nb)
        moved = 0
        biggest = {}
        sizes = np.bincount(comp, minlength=len(label))
        for c in np.unique(comp):
            lab = int(label[c])
            if lab in keep:
                continue
            if lab not in biggest or sizes[c] > sizes[biggest[lab]]:
                biggest[lab] = c
        for c in np.unique(comp):
            lab = int(label[c])
            if lab in keep or biggest.get(lab) == c:
                continue
            idx = np.where(comp == c)[0]
            around = label[nb[idx][nb[idx] >= 0]]
            around = around[around != lab]
            if len(around) == 0:
                continue
            label[idx] = np.bincount(around).argmax()
            moved += len(idx)
        if moved == 0:
            break
    return label


def radial_owners(keys, points, bones):
    """Bone of every voxel of a radial body. Mantle seeds are the voxels in the mantle's core;
    each tentacle's seeds are the voxels hugging its chain. The rest is grown from the seeds over
    the voxel surface, so each tentacle is one joined piece reaching back to the mantle and no
    slate patch is stranded mid-arm. Speckle where tentacles meet the mantle is smoothed by a
    majority vote, and any piece left cut off joins what it touches most. A run of mantle
    voxels reaching further out than the mantle's radius is a tentacle the skeleton missed: it
    gets a chain of its own. Returns the owners (bones may gain chains)."""
    nb = neighbour_table(keys)
    names = [b["name"] for b in bones]
    centre, mantle_r, W = MANTLE_ZONE["centre"], MANTLE_ZONE["radius"], MANTLE_ZONE["width"]
    flat = np.linalg.norm(points[:, :2] - centre, axis=1)
    cell = np.ptp(points[:, 0]) / max(1, np.ptp(keys[:, 0]))
    owner = np.full(len(points), -1)
    for _ in range(6):
        chain = np.array([chain_index(n) for n in names])
        chains = chain.max() + 1
        label = np.full(len(points), -1)
        seeds = (flat < mantle_r * MANTLE_SEED) & (points[:, 2] > MANTLE_ZONE["floor"])
        label[seeds] = 0
        # A tentacle may only grow over voxels near its own chain (its surface path is off
        # centre, so the bound is generous); the mantle may take anything.
        allow = np.ones((len(points), chains), bool)
        for c in range(1, chains):
            own = np.where(chain == c)[0]
            ds = np.stack([_seg_dist(points, bones[i]) for i in own])
            # It tapers: each bone may claim less the further out along the chain it is.
            taper = np.linspace(TENTACLE_THICK[0], TENTACLE_THICK[1], len(own))[:, None]
            label[(ds.min(0) < W * TENTACLE_THICK[1]) & (label < 0)] = c
            allow[:, c] = (ds < W * taper * TENTACLE_REACH).any(0)
        label = grow(label, nb, allow)
        label = grow(label, nb)
        label[label < 0] = 0
        for _ in range(2):
            around = np.where(nb >= 0, label[np.maximum(nb, 0)], -1)
            vote = majority(np.c_[around, label, label])  # a voxel's own label counts twice
            label = vote
        label = join_fragments(label, nb)
        label = adopt_islands(points, label, nb, bones, chain)
        added = missed_tentacle(points, label, nb, bones, seeds, mantle_r, cell)
        if not added:
            break
        names = [b["name"] for b in bones]
    # Within a chain, each voxel goes to the nearest of that chain's own bones.
    chain = np.array([chain_index(n) for n in names])
    for c in range(chains):
        sel = np.where(label == c)[0]
        own = np.where(chain == c)[0]
        d = np.stack([_seg_dist(points[sel], bones[i]) for i in own])
        owner[sel] = own[np.argmin(d, axis=0)]
    return owner


MANDIBLE_REACH = 0.3


def split_mandibles(keys, points, owner, bones):
    """Cuts the mantis's mouthparts off the head into two bones, mandible_l and mandible_r: the
    head voxels within MANDIBLE_REACH of the head's length from the mouth, split left and right,
    each hinged at its upper end. Returns the new owners (bones gains the mandibles)."""
    names = [b["name"] for b in bones]
    if "head0" not in names:
        return owner
    hi = names.index("head0")
    neck, mouth = np.array(bones[hi]["head"]), np.array(bones[hi]["tail"])
    reach = np.linalg.norm(mouth - neck) * MANDIBLE_REACH
    out = owner.copy()
    for side, sx in (("l", 1), ("r", -1)):
        part = np.where((owner == hi) & (np.linalg.norm(points - mouth, axis=1) < reach)
                        & (np.sign(points[:, 0] - mouth[0]) == sx))[0]
        if len(part) < 8:
            continue
        # Only its largest joined piece moves (a stray bit would float off the face).
        nb = neighbour_table(keys[part])
        comp = pieces(np.zeros(len(part), int), nb)
        part = part[comp == np.bincount(comp).argmax()]
        pts = points[part]
        tip = pts[np.argmin(np.linalg.norm(pts - mouth, axis=1))]
        hinge = pts[np.argmax(pts[:, 2])]  # its upper end, where it joins the face
        bones.append({"name": f"mandible_{side}", "parent": "head0", "head": hinge, "tail": tip,
                      "physics": False})
        out[part] = len(bones) - 1
        print(f"mandible_{side}: {len(part)} voxels")
    return out


def whole_limbs(keys, points, owner, bones):
    """A piece of a limb cut off from the rest of that limb floats when it moves: it joins the
    limb (or body) it touches most, onto the nearest of that limb's bones."""
    names = [b["name"] for b in bones]
    chains = sorted(set(n.rstrip("0123456789") for n in names))
    of = np.array([chains.index(n.rstrip("0123456789")) for n in names])
    nb = neighbour_table(keys)
    label = join_fragments(of[owner], nb)
    moved = np.where(label != of[owner])[0]
    for i in moved:
        own = np.where(of == label[i])[0]
        owner[i] = own[np.argmin([_seg_dist(points[i:i + 1], bones[j])[0] for j in own])]
    print(f"limb fragments rejoined: {len(moved)} voxels")
    return owner


def chain_index(name):
    """0 for the mantle, k + 1 for tentacle k."""
    return int(name[len("tentacle"):].split("_")[0]) + 1 if name.startswith("tentacle") else 0


def walk_from(nb, starts, n):
    """walk() from several starts at once."""
    steps = np.full(n, -1)
    steps[starts] = 0
    frontier = np.asarray(starts)
    k = 0
    while len(frontier):
        k += 1
        nxt = nb[frontier].ravel()
        nxt = np.unique(nxt[nxt >= 0])
        nxt = nxt[steps[nxt] < 0]
        steps[nxt] = k
        frontier = nxt
    return np.maximum(steps, 0)


def walk(nb, start, n):
    """Steps from `start` to every voxel it reaches over the neighbour table (-1 unreached)."""
    steps = np.full(n, -1)
    steps[start] = 0
    frontier = np.array([start])
    k = 0
    while len(frontier):
        k += 1
        nxt = nb[frontier].ravel()
        nxt = np.unique(nxt[nxt >= 0])
        nxt = nxt[steps[nxt] < 0]
        steps[nxt] = k
        frontier = nxt
    return steps


def adopt_islands(points, label, nb, bones, chain):
    """A loose piece of mantle (a tentacle tip the sculpt left unjoined) goes to the nearest chain."""
    comp = pieces(label, nb)
    body = comp[label == 0]
    if len(body) == 0:
        return label
    main = np.bincount(body).argmax()
    loose = np.where((label == 0) & (comp != main))[0]
    if len(loose) == 0 or chain.max() == 0:
        return label
    for c in np.unique(comp[loose]):
        idx = np.where(comp == c)[0]
        d = [np.min([_seg_dist(points[idx], bones[i]).min() for i in np.where(chain == k)[0]])
             for k in range(1, chain.max() + 1)]
        label[idx] = 1 + int(np.argmin(d))
    return label


def missed_tentacle(points, label, nb, bones, seeds, mantle_r, cell, segments=6):
    """Adds a chain for the longest thin run of mantle voxels reaching further (walked voxel to
    voxel from the mantle's core) than the mantle's radius and ending out past it: an arm the
    skeleton search missed. The head's own shell is broad, an arm is thin. True if one was added."""
    body = np.where(label == 0)[0]
    # The mantle as it ended up (raised arms inflate the skeleton's estimate): its upper half.
    flat = np.linalg.norm(points[body, :2] - MANTLE_ZONE["centre"], axis=1)
    upper = points[body, 2] > np.median(points[body, 2])
    mantle_r = min(mantle_r, float(np.median(flat[upper])) * 1.4) if upper.any() else mantle_r
    remap = np.full(len(points), -1)
    remap[body] = np.arange(len(body))
    nb_b = np.where(nb[body] >= 0, remap[np.maximum(nb[body], 0)], -1)
    steps = walk_from(nb_b, np.where(seeds[body])[0], len(body))
    out = steps * cell > mantle_r * 0.5
    if not out.any():
        return False
    sub = np.where(out)[0]
    remap2 = np.full(len(body), -1)
    remap2[sub] = np.arange(len(sub))
    nb_sub = np.where(nb_b[sub] >= 0, remap2[np.maximum(nb_b[sub], 0)], -1)
    comp = pieces(np.zeros(len(sub), int), nb_sub)
    best = None
    for c in np.unique(comp):
        idx = np.where(comp == c)[0]
        if len(idx) < 20:
            continue
        run = walk(nb_sub, idx[np.argmin(steps[sub[idx]])], len(sub))
        span = (run.max() * cell) + mantle_r * 0.5
        thick = len(idx) / max(1, run.max())
        # An arm's tip is out past the mantle; the far side of the head's own shell is not.
        tip = points[body[sub[idx[np.argmax(run[idx])]]]]
        out_far = np.linalg.norm(tip[:2] - MANTLE_ZONE["centre"]) > mantle_r * 1.15
        if span > mantle_r and thick < ARM_PER_STEP and out_far and (best is None or span > best[0]):
            best = (span, idx, run)
    if best is None:
        return False
    sub = body[sub]
    idx, steps = best[1], best[2]
    tip = int(np.argmax(steps))
    # Path back: from the tip, always to a neighbour one step nearer.
    path = [tip]
    while steps[path[-1]] > 0:
        cand = nb_sub[path[-1]]
        cand = cand[cand >= 0]
        path.append(int(cand[np.argmin(steps[cand])]))
    pts = points[sub[np.array(path)]]
    joints = [at_arc(pts, f) for f in np.linspace(0.0, 1.0, segments + 1)]
    k = max(chain_index(b["name"]) for b in bones)
    parent = "mantle0"
    for j in range(segments):
        name = f"tentacle{k}_{j}"
        bones.append({"name": name, "parent": parent, "head": np.asarray(joints[segments - j]),
                      "tail": np.asarray(joints[segments - j - 1]), "physics": True})
        parent = name
    print(f"radial: added a chain for a missed arm ({best[0]:.3f} long, {len(idx)} voxels)")
    return True


def nearest_bone(points, bones, side_of, penalty=None):
    """Index of the bone whose segment is nearest each point (limbs stay on their own side)."""
    best = np.full(len(points), -1)
    best_d = np.full(len(points), np.inf)
    for i, b in enumerate(bones):
        a, c = np.array(b["head"]), np.array(b["tail"])
        ab = c - a
        t = np.clip(((points - a) @ ab) / max(1e-9, ab @ ab), 0, 1)
        d = np.linalg.norm(points - (a + t[:, None] * ab), axis=1)
        kind = b["name"].split("_")[0].rstrip("0123456789")
        if penalty and b["name"].endswith("0") and kind in penalty:
            d = d * penalty[kind]  # a limb root must not take body voxels
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
    body_plan = {"insectoid": "hexapod", "cephalopod": "radial"}.get(species, "biped")
    if body_plan == "hexapod":
        bones = hexapod_skeleton(v, tris, lo, hi)
    elif body_plan == "radial":
        bones = radial_skeleton(v, tris, lo, hi)
    else:
        bones = biped_skeleton(v, lo, hi)
    scale = (height - 1) / H
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    cells = surface_voxels(v, tris, col, scale, origin, texture)
    print("colours from", "texture" if texture is not None else "species palette")
    keys = np.array(list(cells.keys()))
    centres_bl = (keys + 0.5) / scale + origin  # back to Blender space for bone tests
    side = lambda name: 1 if "_l" in name else (-1 if "_r" in name else 0)
    owner = nearest_bone(centres_bl, bones, side, ROOT_PENALTY if body_plan != "biped" else None)
    if HEAD_ZONE:
        names = [b["name"] for b in bones]
        in_head = (centres_bl[:, 2] > HEAD_ZONE["neck_z"]) & (
            np.linalg.norm(centres_bl - HEAD_ZONE["centre"], axis=1) < HEAD_ZONE["radius"])
        keep = np.array([names[o].startswith("arm") for o in owner])
        owner[in_head & ~keep] = names.index("head0")
    if body_plan == "radial":
        owner = radial_owners(keys, centres_bl, bones)
    if body_plan == "biped":
        owner = reclaim_plates(centres_bl, owner, bones)
        rgb = np.array([[r / cnt, gr / cnt, b / cnt] for r, gr, b, cnt in cells.values()])
        owner = split_jaw(centres_bl, owner, bones, 1.0 / scale, rgb)
    values = list(cells.values())
    keys, values, owner = close_jaw(keys, values, owner, bones, scale, origin, jaw_shut)
    if body_plan != "radial":
        owner = adopt_orphans(keys, owner)
        if body_plan == "hexapod":
            owner = split_mandibles(keys, centres_bl, owner, bones)
            owner = whole_limbs(keys, centres_bl, owner, bones)
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
    rig = {"height": height, "type": body_plan, "bones": []}
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
