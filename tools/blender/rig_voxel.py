"""Turns a rig-ready kaiju mesh (Tripo Smart Mesh GLB, T-pose, facing -Y) into the game's rigged voxel
model: colours it (dark hide, lighter belly, bone-coloured spikes and claws), fits a skeleton by
tracing the body's own limbs, voxelizes the surface and tags every voxel with its bone.

    blender -b --python tools/blender/rig_voxel.py -- <in.glb> <out_basename> <species> <height_vox>

Writes <out>.kvox (version 2, one pose; each voxel's flags byte is its bone index) and <out>.rig.json
(type "biped", "hexapod" or "radial"; bones: name, parent, head, tail in voxel units with y up and -Z forward,
plus "physics" chains). The insectoid gets the hexapod skeleton (D-022 mantis), the cephalopod a
radial one (mantle + 8 tentacle chains), the reptilian a biped.
Colours come from data/species.json. Pure Blender + numpy.
"""
import json
import struct
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]


# --- load and normalise ---------------------------------------------------------------------------

def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    tris, verts_all = [], []
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
        for t in mesh.loop_triangles:
            tris.append([base + i for i in t.vertices])
        ev.to_mesh_clear()
    v = np.concatenate([a for a, _ in verts_all])
    n = np.concatenate([b for _, b in verts_all])
    n /= np.maximum(1e-9, np.linalg.norm(n, axis=1, keepdims=True))
    return v, n, np.array(tris)


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
    """Distance over the surface from the nearest source vertex, and each vertex's predecessor."""
    import heapq
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
    return dist, prev


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


def radial_skeleton(v, tris, lo, hi, arms=8, segments=6):
    """Bones for an octopus-like body: a mantle on the midline and `arms` tentacles, each a
    physics chain from the body out to its tip. Tips are the furthest low points in each of
    `arms` sectors around the body; each tentacle follows the surface back to the midline."""
    H = hi[2] - lo[2]
    W = max(hi[0] - lo[0], hi[1] - lo[1])
    centre = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2])
    core = np.where(np.linalg.norm(v[:, :2] - centre, axis=1) < W * 0.06)[0]
    dist, prev = geodesic(v, tris, core)
    reach = np.where(np.isfinite(dist), dist, -1)
    body = v[core]
    base = np.array([centre[0], centre[1], body[:, 2].min() + H * 0.05])
    crown = np.array([centre[0], centre[1], hi[2]])
    bones = [{"name": "mantle0", "parent": None, "head": base, "tail": crown, "physics": False}]
    angle = np.arctan2(v[:, 1] - centre[1], v[:, 0] - centre[0])
    low = v[:, 2] < lo[2] + H * 0.3
    for i in range(arms):
        a0 = -np.pi + i * 2 * np.pi / arms
        sector = np.where(low & (angle >= a0) & (angle < a0 + 2 * np.pi / arms))[0]
        if len(sector) == 0:
            continue
        tip = sector[np.argmax(reach[sector])]
        path = path_to_core(v, prev, tip)
        joints = [at_arc(path, f) for f in np.linspace(0.92, 0.0, segments + 1)]
        parent = "mantle0"
        for j in range(segments):
            name = f"tentacle{i}_{j}"
            bones.append({"name": name, "parent": parent, "head": joints[j], "tail": joints[j + 1],
                          "physics": True})
            parent = name
    for b in bones:
        b["head"], b["tail"] = np.asarray(b["head"]).tolist(), np.asarray(b["tail"]).tolist()
    return bones


# Where the hexapod's head is (set by hexapod_skeleton): voxels above the neck near the head's
# centre belong to the head whatever bone is nearest, so the head turns as one piece.
HEAD_ZONE = {}

# Hexapod limb roots sit against the body; their distance is stretched so body voxels stay on the body.
ROOT_PENALTY = {"leg": 2.0, "hind": 2.0, "arm": 1.4, "antenna": 4.0}


def nearest_bone(points, bones, side_of, penalty=None):
    """Index of the bone whose segment is nearest each point (limbs stay on their own side)."""
    best = np.full(len(points), -1)
    best_d = np.full(len(points), np.inf)
    for i, b in enumerate(bones):
        a, c = np.array(b["head"]), np.array(b["tail"])
        ab = c - a
        t = np.clip(((points - a) @ ab) / max(1e-9, ab @ ab), 0, 1)
        d = np.linalg.norm(points - (a + t[:, None] * ab), axis=1)
        kind = b["name"].split("_")[0]
        if penalty and b["name"].endswith("0") and kind in penalty:
            d = d * penalty[kind]  # a limb root must not take body voxels
        s = side_of(b["name"])
        if s != 0:
            d = np.where(np.sign(points[:, 0]) == s, d, d + 1e3)
        better = d < best_d
        best[better], best_d[better] = i, d[better]
    return best


# --- voxelize -------------------------------------------------------------------------------------

def surface_voxels(v, tris, col, scale, origin):
    cells = {}
    for a, b, c in tris:
        q = (v[[a, b, c]] - origin) * scale
        edge = max(np.linalg.norm(q[1] - q[0]), np.linalg.norm(q[2] - q[1]), np.linalg.norm(q[0] - q[2]))
        n = max(2, int(edge * 2) + 1)
        u, w = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
        u, w = u.ravel(), w.ravel()
        k = u + w <= 1
        u, w = u[k], w[k]
        bary = np.c_[1 - u - w, u, w]
        pts = bary @ q
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
    defs = json.loads((ROOT / "data/species.json").read_text(encoding="utf-8"))["species"]
    hexes = next(d for d in defs if d["id"] == species)["colors"]
    colors = {k: [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] for k, h in hexes.items()}
    v, n, tris = load(src)
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
    cells = surface_voxels(v, tris, col, scale, origin)
    keys = np.array(list(cells.keys()))
    centres_bl = (keys + 0.5) / scale + origin  # back to Blender space for bone tests
    side = lambda name: 1 if "_l" in name else (-1 if "_r" in name else 0)
    owner = nearest_bone(centres_bl, bones, side, ROOT_PENALTY if body_plan == "hexapod" else None)
    if HEAD_ZONE:
        names = [b["name"] for b in bones]
        in_head = (centres_bl[:, 2] > HEAD_ZONE["neck_z"]) & (
            np.linalg.norm(centres_bl - HEAD_ZONE["centre"], axis=1) < HEAD_ZONE["radius"])
        keep = np.array([names[o].startswith("arm") for o in owner])
        owner[in_head & ~keep] = names.index("head0")
    # Write voxels (game axes) with their bone index in the flags byte.
    gk = to_game(keys.astype(float))
    gk[:, 0] -= 1  # keep integer cells after the x flip
    with open(out.with_suffix(".kvox"), "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, 1, height))
        f.write(struct.pack("<I", len(cells)))
        for g, (r, gr, b, cnt), bone in zip(gk.astype(int), cells.values(), owner):
            # Species colours are already display (sRGB) values: no gamma here.
            rgb = [int(max(0, min(255, round(x / cnt * 255)))) for x in (r, gr, b)]
            f.write(struct.pack("<hhhBBBB", g[0], g[1], g[2], *rgb, int(bone)))
    rig = {"height": height, "type": body_plan, "bones": []}
    for b in bones:
        head = to_game(((np.array(b["head"]) - origin) * scale)[None])[0]
        tail = to_game(((np.array(b["tail"]) - origin) * scale)[None])[0]
        rig["bones"].append({"name": b["name"], "parent": b["parent"], "head": head.round(2).tolist(),
                             "tail": tail.round(2).tolist(), "physics": b["physics"]})
    out.with_suffix(".rig.json").write_text(json.dumps(rig, indent=1), encoding="utf-8")
    counts = np.bincount(owner, minlength=len(bones))
    print(f"rigged {src}: {len(cells)} voxels, {len(bones)} bones; voxels per bone min {counts.min()}")


main()
