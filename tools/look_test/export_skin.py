"""Look test (throwaway, 2026-10-17): turns the same Tripo GLB the voxel rig was built from into a
skinned mesh for the game's KaijuRig skeleton.

    blender -b --python tools/look_test/export_skin.py -- <in.glb> <rig_base> <out_dir>

<rig_base> is assets/kaiju/reptilian_adult (its .rig.json and .kvox). The mesh is placed exactly
where rig_voxel.py put the voxels (same origin, scale and axis swap, so it lines up with panel A),
and each vertex is weighted by the bones of the voxels around it (A's own bone split, so all three
panels bend the same bones), then the weights are smoothed along the surface so joints blend
instead of tearing. Writes <out_dir>/skin.kmesh and <out_dir>/skin_albedo.jpg.

Also writes <out_dir>/voxel.kmesh for panel C: A's own voxels as one watertight skinned surface.
Every exposed cube face is kept, and every cube corner is a lattice point whose weights are the
average of the cells touching it, so neighbouring cubes share corners and can never part: the
body stays blocks, the joints bend like B's skin.

kmesh: "KMSH", u32 verts, u32 tris, then per vertex f32 pos[3] (voxel units, game axes),
f32 normal[3], f32 uv[2], u8 rgba[4] (sRGB), u8 bones[4], f32 weights[4]; then u32 indices[3 * tris].
"""
import json
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils.kdtree import KDTree

GATHER_RADIUS = 2.0  # voxels: a vertex takes the bones of the voxels this close


def to_game(p):
    return np.c_[-p[..., 0], p[..., 2], p[..., 1]]


def read_kvox(path):
    data = Path(path).read_bytes()
    assert data[:4] == b"KVOX"
    version, count = struct.unpack_from("<II", data, 4)
    height = struct.unpack_from("<H", data, 12)[0]
    n = struct.unpack_from("<I", data, 14)[0]
    rec = np.frombuffer(data, dtype=np.dtype([("x", "<i2"), ("y", "<i2"), ("z", "<i2"), ("r", "u1"),
                                              ("g", "u1"), ("b", "u1"), ("f", "u1")]), count=n, offset=18)
    cells = np.c_[rec["x"], rec["y"], rec["z"]].astype(float)
    return height, cells, rec["f"].astype(int), np.c_[rec["r"], rec["g"], rec["b"]]


LATTICE_PASSES = 12  # voxel-lattice smoothing of A's one-bone-per-voxel split (joint blend width)
FILL_INSET = 0.25  # voxels: the filler lattice sits this far inside the rigid cubes
COLOR_NOISE = 0.08  # data/looks.json color_noise: the per-cell brightness jitter A draws with
DIRS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def write_kmesh(path, pos, nrm, uv, rgba, bones, weights, tris, centres=None):
    """centres given: magic "KMS2", each vertex also carries f32 centre[3] (its cube's rest centre)."""
    with open(path, "wb") as f:
        f.write(b"KMSH" if centres is None else b"KMS2")
        f.write(struct.pack("<II", len(pos), len(tris)))
        for i in range(len(pos)):
            f.write(struct.pack("<3f3f2f4B", *pos[i], *nrm[i], *uv[i], *rgba[i]))
            f.write(struct.pack("<4B4f", *[int(b) for b in bones[i]], *weights[i]))
            if centres is not None:
                f.write(struct.pack("<3f", *centres[i]))
        f.write(np.asarray(tris, dtype="<u4").tobytes())


def top4(w):
    top = np.argsort(-w, axis=1)[:, :4]
    tw = np.take_along_axis(w, top, 1)
    return top, tw / np.maximum(1e-9, tw.sum(1, keepdims=True))


def lattice_weights(cells, owner, bones):
    """A's one-bone-per-voxel split smoothed over the voxel lattice: the skin weights of B and C.
    Only bones that form a joint (same, parent, child) blend: where a thigh lies against the tail
    in the bind pose they stay separate parts, as they move."""
    nb = len(bones)
    names = [b["name"] for b in bones]
    related = np.eye(nb, dtype=bool)
    for i, b in enumerate(bones):
        if b["parent"] is not None:
            j = names.index(b["parent"])
            related[i, j] = related[j, i] = True
    ci = cells.astype(int)
    index = {tuple(c): i for i, c in enumerate(ci)}
    nbr = np.array([[index.get((c[0] + d[0], c[1] + d[1], c[2] + d[2]), -1) for d in DIRS] for c in ci])
    w = np.zeros((len(ci), nb))
    w[np.arange(len(ci)), owner] = 1.0
    for _ in range(LATTICE_PASSES):
        acc = w.copy()
        cnt = np.ones((len(ci), 1))
        for k in range(6):
            has = nbr[:, k] >= 0
            has[has] = related[owner[has], owner[nbr[has, k]]]
            acc[has] += w[nbr[has, k]]
            cnt[has] += 1
        w = acc / cnt
    return w, related, nbr


def voxel_surface(cells, rgb, owner, w, related, nbr, nb, out):
    """Panel C: exposed faces of A's voxels; each corner averages the cells touching it."""
    ci = cells.astype(int)
    corner_cells = {}
    for i, c in enumerate(ci):
        for o in np.ndindex(2, 2, 2):
            corner_cells.setdefault((c[0] + o[0], c[1] + o[1], c[2] + o[2]), []).append(i)

    def corner_weight(key, i):
        """Average over the cells at this lattice point whose bone forms a joint with cell i's."""
        mates = [j for j in corner_cells[key] if related[owner[i], owner[j]]]
        return w[mates].mean(0)
    rng = np.random.default_rng(7)
    pos, nrm, uv, rgba, tris, cell_of = [], [], [], [], [], []
    for i, c in enumerate(ci):
        jit = 1.0 + rng.uniform(-1, 1) * COLOR_NOISE
        col = [int(max(0, min(255, round(x * jit)))) for x in rgb[i]] + [255]
        centre = c + np.array([0.0, 0.5, 0.0])
        for k, d in enumerate(DIRS):
            if nbr[i, k] >= 0:
                continue
            n = np.array(d, dtype=float)
            a = np.array([0.0, 1.0, 0.0]) if abs(n[1]) < 0.5 else np.array([1.0, 0.0, 0.0])
            u = np.cross(a, n) * 0.5
            v = np.cross(n, u / np.linalg.norm(u)) * 0.5
            cc = centre + n * 0.5
            quad = [cc - u - v, cc + u - v, cc + u + v, cc - u + v]
            base = len(pos)
            for q in quad:
                cell_of.append(i)
                pos.append(q)
                nrm.append(n)
                uv.append((0.0, 0.0))
                rgba.append(col)
            tris.append([base + 0, base + 2, base + 1])
            tris.append([base + 0, base + 3, base + 2])
    # A drawn corner q = cell + (0, 0.5, 0) + (+-0.5)^3, so its lattice key is q + (0.5, 0, 0.5).
    lattice = [(int(round(p[0] + 0.5)), int(round(p[1])), int(round(p[2] + 0.5))) for p in pos]
    cache = {}
    cw = np.zeros((len(pos), nb))
    for n, (k, i) in enumerate(zip(lattice, cell_of)):
        ck = (k, owner[i])
        if ck not in cache:
            cache[ck] = corner_weight(k, i)
        cw[n] = cache[ck]
    bones, weights = top4(cw)
    write_kmesh(out / "voxel.kmesh", pos, nrm, uv, rgba, bones, weights, tris)
    # Filler under the rigid cubes: the same watertight lattice, every face a quarter voxel in.
    inset = [p - n * FILL_INSET for p, n in zip(pos, nrm)]
    write_kmesh(out / "voxel_fill.kmesh", inset, nrm, uv, rgba, bones, weights, tris)
    # Round 2: rigid cubes. Every vertex of a cube carries the cube's own weights and centre; the
    # shader (voxel_rigid.gdshader) moves the centre smoothly and turns the cube without shear.
    cell_bones, cell_weights = top4(w)
    cell_of = np.array(cell_of)
    centres = ci[cell_of] + np.array([0.0, 0.5, 0.0])
    write_kmesh(out / "voxel_rigid.kmesh", pos, nrm, uv, rgba, cell_bones[cell_of], cell_weights[cell_of],
                tris, centres)
    print(f"voxel surface: {len(pos)} verts, {len(tris)} tris, {len(corner_cells)} lattice corners")


# Tripo auto-rig (a Mixamo humanoid) -> KaijuRig bones. Left/Right are Blender +x/-x, which are
# our "_l"/"_r". Hands and fingers fold into the last arm bone, feet and toes into the last leg
# bone. It has no tail and no jaw: those vertices keep the lattice weights (see tripo_weights).
TRIPO_MAP = {"Hips": "spine0", "Spine": "spine0", "Spine1": "spine1", "Spine2": "spine2",
             "Neck": "head0", "Head": "head1", "HeadTop_End": "head1"}
for _side, _ours in (("Left", "l"), ("Right", "r")):
    TRIPO_MAP.update({f"{_side}UpLeg": f"leg_{_ours}0", f"{_side}Leg": f"leg_{_ours}1",
                      f"{_side}Foot": f"leg_{_ours}2", f"{_side}ToeBase": f"leg_{_ours}2",
                      f"{_side}Toe_End": f"leg_{_ours}2", f"{_side}Shoulder": "spine2",
                      f"{_side}Arm": f"arm_{_ours}0", f"{_side}ForeArm": f"arm_{_ours}1",
                      f"{_side}Hand": f"arm_{_ours}2"})


def tripo_weights(path, names):
    """Per-vertex weights of a Tripo auto-rigged GLB mapped onto our bones, with the vertices in
    world space (normalise them like the textured mesh). Unmapped groups are reported."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    obj = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    mw = np.array(obj.matrix_world)
    v = np.array([x.co for x in obj.data.vertices])
    v = (np.c_[v, np.ones(len(v))] @ mw.T)[:, :3]
    col = {}
    unmapped = set()
    for vg in obj.vertex_groups:
        base = vg.name.split(":")[-1]
        key = base[:base.index("Hand") + 4] if base.startswith(("LeftHand", "RightHand")) else base
        if key not in TRIPO_MAP:
            unmapped.add(vg.name)
            continue
        col[vg.index] = names.index(TRIPO_MAP[key])
    w = np.zeros((len(v), len(names)))
    for x in obj.data.vertices:
        for ge in x.groups:
            if ge.group in col:
                w[x.index, col[ge.group]] += ge.weight
    print(f"tripo rig: {len(obj.vertex_groups)} groups, unmapped {sorted(unmapped)}; "
          f"{(w.sum(1) <= 0).sum()} vertices unweighted")
    return v, w


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, rig_base, out = args[0], args[1], Path(args[2])
    tripo = next((a.split("=", 1)[1] for a in args if a.startswith("--tripo_rig=")), None)
    out.mkdir(parents=True, exist_ok=True)
    rig = json.loads(Path(rig_base + ".rig.json").read_text(encoding="utf-8"))
    height, cells, owner, rgb = read_kvox(rig_base + ".kvox")
    bones = rig["bones"]
    names = [b["name"] for b in bones]
    if tripo:
        tv, tw_rig = tripo_weights(tripo, names)
    print(f"kvox {len(cells)} voxels, {len(bones)} bones, height {height}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(objs) == 1, "expects one Tripo mesh"
    obj = objs[0]
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = obj.evaluated_get(deps).to_mesh()
    mesh.calc_loop_triangles()
    mw = np.array(obj.matrix_world)
    v = np.array([x.co for x in mesh.vertices])
    v = (np.c_[v, np.ones(len(v))] @ mw.T)[:, :3]
    nrm = np.array([x.normal for x in mesh.vertices]) @ mw[:3, :3].T
    nrm /= np.maximum(1e-9, np.linalg.norm(nrm, axis=1, keepdims=True))
    # Same normalisation as rig_voxel.py, then the half-voxel shift the voxel builder draws with.
    lo, hi = v.min(0), v.max(0)
    scale = (height - 1) / (hi[2] - lo[2])
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    g = to_game((v - origin) * scale) - np.array([0.5, 0.0, 0.5])
    gn = to_game(nrm)

    # Bone weights: the lattice-smoothed field of the voxels around each vertex (drawn cell
    # centres sit at y + 0.5), taking only cells whose bone forms a joint with the nearest one.
    nb = len(bones)
    cell_w, related, nbr = lattice_weights(cells, owner, bones)
    centres = cells + np.array([0.0, 0.5, 0.0])
    tree = KDTree(len(centres))
    for i, c in enumerate(centres):
        tree.insert(c, i)
    tree.balance()
    w = np.zeros((len(g), nb))
    for i, p in enumerate(g):
        _co, near_i, _d = tree.find(p)
        for _co, idx, dist in tree.find_range(p, max(GATHER_RADIUS, _d + 0.5)):
            if related[owner[near_i], owner[idx]]:
                w[i] += cell_w[idx] * np.exp(-(dist / GATHER_RADIUS) ** 2)
        if w[i].sum() <= 0:
            w[i] = cell_w[near_i]
    if tripo:
        # Tripo's weights everywhere its rig has the bones; the tail and jaw (no Tripo bones) keep
        # the lattice weights, blended in by how much of each vertex the lattice gives them.
        tlo, thi = tv.min(0), tv.max(0)
        tg = to_game((tv - np.array([(tlo[0] + thi[0]) / 2, (tlo[1] + thi[1]) / 2, tlo[2]]))
                     * ((height - 1) / (thi[2] - tlo[2]))) - np.array([0.5, 0.0, 0.5])
        ttree = KDTree(len(tg))
        for i, c in enumerate(tg):
            ttree.insert(c, i)
        ttree.balance()
        own = np.array([n.startswith("tail") or n == "jaw" for n in names])
        w /= np.maximum(1e-9, w.sum(1, keepdims=True))
        far = 0.0
        for i, p in enumerate(g):
            _co, k, d = ttree.find(p)
            far = max(far, d)
            f = w[i, own].sum()
            t = tw_rig[k].copy()
            t[own] = 0.0
            t = t / t.sum() if t.sum() > 0 else w[i]
            w[i] = w[i] * f + t * (1.0 - f)
        print(f"tripo mesh matched to the textured mesh within {far:.2f} voxels")
    top = np.argsort(-w, axis=1)[:, :4]
    tw = np.take_along_axis(w, top, 1)
    tw /= np.maximum(1e-9, tw.sum(1, keepdims=True))

    # Split vertices on UV seams: one output vertex per (mesh vertex, uv).
    uv_layer = mesh.uv_layers.active.data
    key_of, verts, tris = {}, [], []
    for t in mesh.loop_triangles:
        tri = []
        for vi, li in zip(t.vertices, t.loops):
            uv = uv_layer[li].uv
            k = (vi, round(uv[0], 5), round(uv[1], 5))
            if k not in key_of:
                key_of[k] = len(verts)
                verts.append((vi, uv[0], 1.0 - uv[1]))
            tri.append(key_of[k])
        # The x flip to game axes mirrors the mesh: reverse each triangle to keep it outward.
        tris.append([tri[0], tri[2], tri[1]])
    pos = [g[vi] for vi, _u, _v in verts]
    nrm = [gn[vi] for vi, _u, _v in verts]
    uvs = [(u, vv) for _vi, u, vv in verts]
    white = [(255, 255, 255, 255)] * len(verts)
    write_kmesh(out / ("skin_tripo.kmesh" if tripo else "skin.kmesh"), pos, nrm, uvs, white, top[[vi for vi, _u, _v in verts]],
                tw[[vi for vi, _u, _v in verts]], tris)
    # Albedo texture, as is (sRGB): the packed file's own bytes, so always skin_albedo.jpg.
    mat = obj.material_slots[0].material
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            img = node.image
            if img.packed_file is not None and img.packed_file.data[:2] == bytes([0xFF, 0xD8]):
                (out / "skin_albedo.jpg").write_bytes(img.packed_file.data)
            else:
                img.filepath_raw = str(out / "skin_albedo.jpg")
                img.file_format = "JPEG"
                img.save()
            break
    near = np.array([tree.find(p)[2] for p in g[::50]])
    print(f"mesh to voxel alignment: median {np.median(near):.2f} voxels, 95% {np.percentile(near, 95):.2f}")
    voxel_surface(cells, rgb, owner, cell_w, related, nbr, nb, out)
    hard = (tw[:, 0] > 0.98).mean()
    print(f"wrote {len(verts)} verts, {len(tris)} tris; {hard * 100:.0f}% of vertices on one bone")


main()
