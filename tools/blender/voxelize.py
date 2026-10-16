"""Voxelizes a textured model (GLB/FBX/OBJ) into the game's .kvox format: the surface shell of
the model on a regular grid, each voxel coloured from the model's base-colour texture.

    blender -b --python tools/blender/voxelize.py -- <in.glb> <out.kvox> <height_in_voxels>

.kvox (little-endian): b"KVOX", uint32 version (1), uint32 count, uint16 height, then per voxel
int16 x, int16 y, int16 z, uint8 r, uint8 g, uint8 b, uint8 flags (0). y is up, the model faces
-Z, feet rest on y = 0, x and z are centred. Pure Blender + numpy, no add-ons.
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
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)[:, :, :3]
        cache[img.name] = px
    return cache[img.name]


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    src, dst, height = args[0], args[1], int(args[2])
    objects = load(src)
    tris = triangles(objects)
    allp = np.concatenate([t[0] for t in tris])
    lo, hi = allp.min(axis=0), allp.max(axis=0)
    # Blender is Z-up; the game is Y-up. Scale so the model is `height` voxels tall.
    scale = (height - 1) / max(1e-6, hi[2] - lo[2])
    centre = (lo + hi) / 2.0
    cells = {}
    cache = {}
    for p, uv, mat in tris:
        q = (p - np.array([centre[0], centre[1], lo[2]])) * scale
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
    with open(dst, "wb") as f:
        f.write(b"KVOX")
        f.write(struct.pack("<IIH", 1, len(cells), height))
        for (x, y, z), (r, g, b, n) in cells.items():
            rgb = [int(max(0, min(255, round((v / n) ** (1 / 2.2) * 255)))) for v in (r, g, b)]
            f.write(struct.pack("<hhhBBBB", x, y, z, rgb[0], rgb[1], rgb[2], 0))
    print(f"voxelized {src}: {len(cells)} voxels, {height} tall -> {dst}")


main()
