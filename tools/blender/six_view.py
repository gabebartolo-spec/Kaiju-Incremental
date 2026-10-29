"""Six-view inspection renders of a generated model (front, back, left, right, three-quarter, top),
textured as imported and as grey clay, for the generated-asset inspection rule.

    blender -b --python tools/blender/six_view.py -- <in.glb> <out_dir> [size_px]

Writes <out_dir>/<view>_<textured|clay>.png at size_px square (900 by default) and
<out_dir>/stats.json, the broken-geometry counts an inspection lists (never a judgement of looks):
faces; parts (mesh islands joined by edges); floating parts (an island whose lowest point is more
than 1% of the model's height above the model's ground); tiny parts (under 0.1% of the faces);
hole edges (an edge with one face) and non-manifold edges (three or more faces); size in metres.
Pure Blender + numpy, Eevee.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], Path(args[1])
px = int(args[2]) if len(args) > 2 else 900
out.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
centre = (lo + hi) / 2
size = max(hi - lo)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [
    e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items
] else "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = px
scene.world = bpy.data.worlds.new("w")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
fill.data.energy = 1.2
fill.rotation_euler = (math.radians(60), 0, math.radians(210))
scene.collection.objects.link(fill)

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = size * 1.15
scene.collection.objects.link(cam)
scene.camera = cam



def _roots(nv, ev):
    """Union-find over the edges: each vertex's island root."""
    parent = list(range(nv))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in ev.tolist():
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    return np.array([find(v) for v in range(nv)])


def geometry_stats(objs, floor, tall):
    """The broken-geometry counts over every mesh object (see the module doc)."""
    s = {"faces": 0, "parts": 0, "floating_parts": 0, "hole_edges": 0, "non_manifold_edges": 0}
    sizes = []
    for o in objs:
        me = o.data
        nv, nl, npoly = len(me.vertices), len(me.loops), len(me.polygons)
        s["faces"] += npoly
        co = np.empty(nv * 3, np.float64)
        me.vertices.foreach_get("co", co)
        co = (np.c_[co.reshape(-1, 3), np.ones(nv)] @ np.array(o.matrix_world).T)[:, :3]
        # glTF splits vertices along UV seams: weld by position (merge by distance) first.
        _, weld = np.unique(np.round(co / (tall * 1e-5)).astype(np.int64), axis=0, return_inverse=True)
        weld = weld.ravel()
        nw = int(weld.max()) + 1
        starts = np.empty(npoly, np.int64)
        me.polygons.foreach_get("loop_start", starts)
        totals = np.empty(npoly, np.int64)
        me.polygons.foreach_get("loop_total", totals)
        lv = np.empty(nl, np.int64)
        me.loops.foreach_get("vertex_index", lv)
        lv = weld[lv]
        nxt = np.arange(nl) + 1
        ends = starts + totals
        poly_of = np.repeat(np.arange(npoly), totals)
        nxt = np.where(nxt == ends[poly_of], starts[poly_of], nxt)
        a, b = lv, lv[nxt]
        keys = np.minimum(a, b) * nw + np.maximum(a, b)
        _, uses = np.unique(keys, return_counts=True)
        s["hole_edges"] += int((uses == 1).sum())
        s["non_manifold_edges"] += int((uses > 2).sum())
        roots = _roots(nw, np.unique(np.c_[np.minimum(a, b), np.maximum(a, b)], axis=0))
        z = np.full(nw, np.inf)
        np.minimum.at(z, weld, co[:, 2])
        ids, inv = np.unique(roots, return_inverse=True)
        low = np.full(len(ids), np.inf)
        np.minimum.at(low, inv, z)
        sizes.extend(np.bincount(inv[lv[starts]], minlength=len(ids)).tolist())
        s["parts"] += len(ids)
        s["floating_parts"] += int((low > floor + 0.01 * tall).sum())
    s["tiny_parts"] = sum(1 for c in sizes if c < 0.001 * max(1, s["faces"]))
    return s


stats = geometry_stats(meshes, lo.z, hi.z - lo.z)
stats["size_m"] = [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)]
(out / "stats.json").write_text(json.dumps(stats))
print("stats", json.dumps(stats))

views = {
    "front": Vector((0, -1, 0)), "back": Vector((0, 1, 0)), "left": Vector((-1, 0, 0)),
    "right": Vector((1, 0, 0)), "three_quarter": Vector((0.7, -0.7, 0.35)), "top": Vector((0, -0.01, 1)),
}
clay = bpy.data.materials.new("clay")
clay.use_nodes = True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.7, 0.7, 0.68, 1)
originals = {o.name: [s.material for s in o.material_slots] for o in meshes}

for mode in ("textured", "clay"):
    for o in meshes:
        for i, slot in enumerate(o.material_slots):
            slot.material = clay if mode == "clay" else originals[o.name][i]
        if mode == "clay" and not o.material_slots:
            o.data.materials.append(clay)
    for name, d in views.items():
        cam.location = centre + d.normalized() * size * 3
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out / f"{name}_{mode}.png")
        bpy.ops.render.render(write_still=True)
print("six views written to", out)
