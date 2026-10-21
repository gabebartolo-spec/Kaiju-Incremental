"""Six-view inspection renders of a generated model (front, back, left, right, three-quarter, top),
textured as imported and as grey clay, for the generated-asset inspection rule.

    blender -b --python tools/blender/six_view.py -- <in.glb> <out_dir>

Writes <out_dir>/<view>_<textured|clay>.png at 900x900. Pure Blender, Eevee.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], Path(args[1])
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
scene.render.resolution_x = scene.render.resolution_y = 900
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
