"""Writes the triangles of a Blender skin export's welded mesh (<x>.skinf beside <x>.skinw), so
bake.py can sample each voxel's weights at the closest point on the skin instead of from the
nearest weighted positions (the croc titan's mesh is sparse: its voxels sit a median 1.07 m from
the nearest position, and nearest-position blending leaked a thigh's weight into the tail).

    blender -b --python tools/kaiju_skin/skin_faces.py -- <the GLB the export came from> <x.skin.json>

The GLB is loaded the way tools/blender/rig_voxel.py loads it; its points go through rig_voxel's
cell grid and the export's kvox_cell_to_skin into skin space, where each must land on a welded
position. .skinf: "KSKF", u32 version 1, u32 triangle count, then u32 a, b, c per triangle
(indices into the .skinw positions); triangles that weld down to a line are dropped.
"""
import json
import struct
import sys
from pathlib import Path

import bpy
import numpy as np

WELD_TOLERANCE = 0.05  # skin metres: a GLB point further than this from every welded position fails


def load(path):
    """World-space vertices and triangles of every mesh in the GLB."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    verts, tris, base = [], [], 0
    deps = bpy.context.evaluated_depsgraph_get()
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        mesh = obj.evaluated_get(deps).to_mesh()
        mesh.calc_loop_triangles()
        mw = np.array(obj.matrix_world)
        v = np.array([x.co for x in mesh.vertices])
        verts.append((np.c_[v, np.ones(len(v))] @ mw.T)[:, :3])
        tris += [[base + i for i in t.vertices] for t in mesh.loop_triangles]
        base += len(v)
    return np.concatenate(verts), np.array(tris)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    glb, meta_path = args[0], Path(args[1])
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    v, tris = load(glb)
    # rig_voxel: cell k (Blender axes) = (src - origin) * sc - 0.5, game cell = (-(kx + 1), kz, ky).
    lo, hi = v.min(0), v.max(0)
    sc = (meta["kvox_height"] - 1) / (hi[2] - lo[2])
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    k = (v - origin) * sc - 0.5
    cell = np.c_[-(k[:, 0] + 1), k[:, 2], k[:, 1]]
    m = np.array(meta["kvox_cell_to_skin"], dtype=float)
    p = (np.c_[cell, np.ones(len(cell))] @ m.T)[:, :3]
    raw = (meta_path.parent / meta["weights_file"]).read_bytes()
    count = struct.unpack_from("<I", raw, 8)[0]
    welded = np.frombuffer(raw, dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)], count=count,
                           offset=14)["p"].astype(float)
    ids = np.zeros(len(p), dtype=np.int64)
    worst = 0.0
    for start in range(0, len(p), 1024):
        d2 = ((p[start:start + 1024, None, :] - welded[None]) ** 2).sum(-1)
        ids[start:start + 1024] = np.argmin(d2, axis=1)
        worst = max(worst, float(np.sqrt(d2.min(1)).max()))
    if worst > WELD_TOLERANCE:
        raise SystemExit(f"{glb}: a point lands {worst:.3f} m from every welded position (not this export's GLB?)")
    t = ids[tris]
    t = t[(t[:, 0] != t[:, 1]) & (t[:, 1] != t[:, 2]) & (t[:, 0] != t[:, 2])]
    _, first = np.unique(np.sort(t, axis=1), axis=0, return_index=True)  # UV seams repeat triangles
    t = t[np.sort(first)]
    out = (meta_path.parent / meta["weights_file"]).with_suffix(".skinf")
    with open(out, "wb") as f:
        f.write(b"KSKF" + struct.pack("<II", 1, len(t)))
        f.write(t.astype("<u4").tobytes())
    print(f"{out.name}: {len(t)} triangles over {count} welded positions (worst weld {worst:.4f} m)")


main()
