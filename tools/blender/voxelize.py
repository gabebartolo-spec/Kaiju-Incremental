"""Voxelizes a textured model (GLB/FBX/OBJ) into the game's .kvox format: the surface shell of
the model on a regular grid, each voxel coloured from the model's base-colour texture.

    blender -b --python tools/blender/voxelize.py -- <in.glb> <out.kvox> <height_in_voxels> [frames]

With `frames` > 1 the model's first animation (e.g. a rigged walk cycle) is sampled at that many
evenly spaced frames and each pose is voxelized: a flipbook the game steps through while walking.
The scale and centre come from the first frame, so the body does not swim between frames.

.kvox (little-endian): b"KVOX", uint32 version (2), uint32 frame count, uint16 height, then per
frame: uint32 count and per voxel int16 x, int16 y, int16 z, uint8 r, uint8 g, uint8 b,
uint8 flags (0). y is up, the model faces -Z, feet rest on y = 0, x and z are centred.
Pure Blender + numpy, no add-ons.
"""
import struct
import sys

import bpy
import numpy as np


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lower = path.lower()
    if lower.endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    elif lower.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    elif lower.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit(f"unsupported model: {path}")
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def base_image(mat):
    """The image feeding the material's Base Color, or None."""
    if mat is None or not mat.use_nodes:
        return None
    for node in mat.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            link = node.inputs["Base Color"].links
            if link and link[0].from_node.type == "TEX_IMAGE":
                return link[0].from_node.image
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image is not None:
            return node.image
    return None


def base_colour(mat):
    if mat is not None and mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                return np.array(node.inputs["Base Color"].default_value[:3])
    return np.array([0.6, 0.6, 0.6])


def triangles(objects):
    """World-space triangles with UVs and a per-triangle sampler (image pixels or flat colour)."""
    out = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        mw = np.array(obj.matrix_world)
        verts = np.array([v.co for v in mesh.vertices])
        verts = (np.c_[verts, np.ones(len(verts))] @ mw.T)[:, :3]
        uv_layer = mesh.uv_layers.active.data if mesh.uv_layers.active else None
        for tri in mesh.loop_triangles:
            mat = obj.material_slots[tri.material_index].material if obj.material_slots else None
            p = verts[list(tri.vertices)]
            uv = (np.array([uv_layer[i].uv for i in tri.loops]) if uv_layer else np.zeros((3, 2)))
            out.append((p, uv, mat))
        ev.to_mesh_clear()
    return out


def image_array(img, cache):
    if img.name not in cache:
        w, h = img.size
        px = np.empty(w * h * img.channels, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, img.channels)[:, :, :3]
        cache[img.name] = px
    return cache[img.name]


def voxelize(tris, frame_fit):
    """Cells {(x, y, z): [r, g, b, n]} for the triangles, using a fixed (scale, centre, floor)."""
    scale, centre, floor = frame_fit
    cells = {}
    cache = {}
    for p, uv, mat in tris:
        q = (p - np.array([centre[0], centre[1], floor])) * scale
        edge = max(np.linalg.norm(q[1] - q[0]), np.linalg.norm(q[2] - q[1]), np.linalg.norm(q[0] - q[2]))
        n = max(2, int(edge * 2.0) + 1)
        a, b = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
        a, b = a.ravel(), b.ravel()
        keep = a + b <= 1.0
        a, b = a[keep], b[keep]
        c = 1.0 - a - b
        pts = c[:, None] * q[0] + a[:, None] * q[1] + b[:, None] * q[2]
        img = base_image(mat)
        if img is not None and img.size[0] > 0:
            px = image_array(img, cache)
            h, w = px.shape[:2]
            uvs = c[:, None] * uv[0] + a[:, None] * uv[1] + b[:, None] * uv[2]
            ix = np.clip((uvs[:, 0] % 1.0) * (w - 1), 0, w - 1).astype(int)
            iy = np.clip((uvs[:, 1] % 1.0) * (h - 1), 0, h - 1).astype(int)
            cols = px[iy, ix]
        else:
            cols = np.tile(base_colour(mat), (len(pts), 1))
        # Blender (x, y, z) Z-up, facing -Y  ->  game (-x, z, y) Y-up, facing -Z (a rotation,
        # not a mirror: glTF imports face -Y in Blender).
        keys = np.floor(np.c_[-pts[:, 0], pts[:, 2], pts[:, 1]]).astype(int)
        for k, col in zip(map(tuple, keys), cols):
            acc = cells.get(k)
            if acc is None:
                cells[k] = [col[0], col[1], col[2], 1]
            else:
                acc[0] += col[0]
                acc[1] += col[1]
                acc[2] += col[2]
                acc[3] += 1
    return cells


def _samplers(obj, cache):
    """Per material slot: the base-colour image array (h, w, 3) or a flat colour (3,)."""
    out = []
    for slot in obj.material_slots or [None]:
        mat = slot.material if slot is not None else None
        img = base_image(mat)
        if img is not None and img.size[0] > 0:
            out.append(image_array(img, cache))
        else:
            out.append(base_colour(mat))
    return out


def voxelize_fast(objects, height):
    """The same cells as voxelize() for one static pose, vectorised over every triangle at once
    (a Tripo HD model has ~1.8M faces: the per-triangle loop takes hours). Returns
    {(x, y, z): [r, g, b, n]} in the same game axes."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts = []
    cache = {}
    for obj in objects:
        ev = obj.evaluated_get(depsgraph)
        mesh = ev.to_mesh()
        mesh.calc_loop_triangles()
        nt = len(mesh.loop_triangles)
        nv = len(mesh.vertices)
        co = np.empty(nv * 3, np.float64)
        mesh.vertices.foreach_get("co", co)
        co = (np.c_[co.reshape(-1, 3), np.ones(nv)] @ np.array(obj.matrix_world).T)[:, :3]
        tv = np.empty(nt * 3, np.int64)
        mesh.loop_triangles.foreach_get("vertices", tv)
        tl = np.empty(nt * 3, np.int64)
        mesh.loop_triangles.foreach_get("loops", tl)
        tm = np.empty(nt, np.int64)
        mesh.loop_triangles.foreach_get("material_index", tm)
        uv = np.zeros((len(mesh.loops), 2))
        if mesh.uv_layers.active:
            flat = np.empty(len(mesh.loops) * 2, np.float64)
            mesh.uv_layers.active.data.foreach_get("uv", flat)
            uv = flat.reshape(-1, 2)
        parts.append((co[tv.reshape(-1, 3)], uv[tl.reshape(-1, 3)], tm, _samplers(obj, cache)))
        ev.to_mesh_clear()
    allp = np.concatenate([p[0].reshape(-1, 3) for p in parts])
    lo, hi = allp.min(axis=0), allp.max(axis=0)
    scale = (height - 1) / max(1e-6, hi[2] - lo[2])
    base = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    keys_all, cols_all = [], []
    for tris, uvs, mats, samplers in parts:
        q = (tris - base) * scale
        edge = np.max(np.linalg.norm(q - np.roll(q, 1, axis=1), axis=2), axis=1)
        n_of = np.maximum(2, (edge * 2.0).astype(np.int64) + 1)
        for n in np.unique(n_of):
            sel = n_of == n
            a, b = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
            a, b = a.ravel(), b.ravel()
            keep = a + b <= 1.0
            a, b = a[keep], b[keep]
            c = 1.0 - a - b
            w = np.c_[c, a, b]  # (k, 3) barycentric weights
            qs, us, ms = q[sel], uvs[sel], mats[sel]
            pts = np.einsum("kj,tjd->tkd", w, qs).reshape(-1, 3)
            uvp = np.einsum("kj,tjd->tkd", w, us).reshape(-1, 2)
            mp = np.repeat(ms, len(w))
            cols = np.zeros((len(pts), 3))
            for m, s in enumerate(samplers):
                hit = mp == m
                if not hit.any():
                    continue
                if s.ndim == 3:
                    h, wd = s.shape[:2]
                    ix = np.clip((uvp[hit, 0] % 1.0) * (wd - 1), 0, wd - 1).astype(int)
                    iy = np.clip((uvp[hit, 1] % 1.0) * (h - 1), 0, h - 1).astype(int)
                    cols[hit] = s[iy, ix]
                else:
                    cols[hit] = s
            keys_all.append(np.floor(np.c_[-pts[:, 0], pts[:, 2], pts[:, 1]]).astype(np.int64))
            cols_all.append(cols)
    keys = np.concatenate(keys_all)
    cols = np.concatenate(cols_all)
    uniq, inv = np.unique(keys, axis=0, return_inverse=True)
    inv = inv.ravel()
    sums = np.stack([np.bincount(inv, weights=cols[:, k], minlength=len(uniq)) for k in range(3)], axis=1)
    count = np.bincount(inv, minlength=len(uniq))
    return {tuple(k): [s[0], s[1], s[2], n] for k, s, n in zip(uniq.tolist(), sums, count)}


def frame_range():
    """(start, end) of the first action in the scene, or None."""
    for obj in bpy.context.scene.objects:
        ad = obj.animation_data
        if ad is not None and ad.action is not None:
            start, end = ad.action.frame_range
            return int(start), int(end)
    return None


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, dst, height = args[0], args[1], int(args[2])
    frames = int(args[3]) if len(args) > 3 else 1
    objects = load(src)
    span = frame_range()
    if frames > 1 and span is None:
        print("no animation found; writing one frame")
        frames = 1
    poses = []
    fit = None
    if frames == 1:  # one static pose: the vectorised path
        poses.append(voxelize_fast(objects, height))
    for i in range(frames if frames > 1 else 0):
        if frames > 1:
            bpy.context.scene.frame_set(int(span[0] + (span[1] - span[0]) * i / frames))
        tris = triangles(objects)
        if fit is None:
            allp = np.concatenate([t[0] for t in tris])
            lo, hi = allp.min(axis=0), allp.max(axis=0)
            fit = ((height - 1) / max(1e-6, hi[2] - lo[2]), (lo + hi) / 2.0, lo[2])
        poses.append(voxelize(tris, fit))
    with open(dst, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 2, len(poses), height))
        for cells in poses:
            f.write(struct.pack("<I", len(cells)))
            for (x, y, z), (r, g, b, n) in cells.items():
                rgb = [int(max(0, min(255, round((v / n) ** (1 / 2.2) * 255)))) for v in (r, g, b)]
                f.write(struct.pack("<hhhBBBB", x, y, z, rgb[0], rgb[1], rgb[2], 0))
    print(f"voxelized {src}: {len(poses)} frame(s), {sum(len(c) for c in poses)} voxels, {height} tall -> {dst}")


if __name__ == "__main__":
    main()
