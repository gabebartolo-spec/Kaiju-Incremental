"""Builds the attack helicopter (AH-64-like) in Blender from code: body, main rotor, tail rotor.

    blender -b --python assets/source/vehicles/build_heli.py -- <out.blend> <out.glb>

Same conventions as build_tank.py (whose helpers it uses): Z up, ground z = 0 under the wheels,
parts laid out facing +Y, then the Body root turned 180 degrees so the finished model faces -Y
(glTF front, voxelize convention). Real metres: 17.7 m long rotor tip to tail, 14.6 m main
rotor, 4.0 m to the fin top; tandem stepped canopy, stub wings with rocket pods and missile
racks, chin gun, tailwheel gear.

Objects:
    Body            origin on the ground under the mast
      MainRotor     origin on the rotor hub, spins about Z
      TailRotor     origin on the tail-rotor hub, spins about X
      ChinGun       origin on the chin turret, aims at the target
Our own model (no references traced, no generator).
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_tank import box, cyl, material, new_obj, prism_x  # noqa: E402

MAST = Vector((0.0, 0.3, 3.62))       # main rotor hub
ROTOR_R = 7.3                         # 14.6 m disc
TAIL_HUB = Vector((-0.32, -8.25, 3.45))
TAIL_R = 1.4
GUN = Vector((0.0, 6.78, 0.86))     # chin turret pivot

PALETTE = {
    "tan": "#b89c6a",
    "tan_dark": "#8f774e",
    "glass": "#2e3b45",
    "rotor": "#2b2b28",
    "metal": "#3a3a38",
    "tyre": "#1e1d1b",
}

# fuselage sections: y, half width, bottom z, top z (nose to tail boom end)
SECTIONS = [
    (7.6, 0.30, 1.20, 1.65),
    (7.0, 0.52, 0.95, 2.00),
    (5.5, 0.60, 0.85, 2.30),
    (4.3, 0.66, 0.85, 2.55),
    (2.8, 0.80, 0.85, 2.75),
    (0.5, 0.85, 0.90, 2.80),
    (-1.8, 0.70, 1.05, 2.60),
    (-3.0, 0.36, 1.55, 2.32),
    (-8.6, 0.20, 1.98, 2.32),
]


def fuselage(bm, mi):
    """Loft an eight-sided ring through each section, capped at both ends."""
    rings = []
    for y, hw, zb, zt in SECTIONS:
        h = zt - zb
        pts = [(0.6 * hw, zt), (hw, zt - 0.25 * h), (hw, zb + 0.3 * h), (0.6 * hw, zb),
               (-0.6 * hw, zb), (-hw, zb + 0.3 * h), (-hw, zt - 0.25 * h), (-0.6 * hw, zt)]
        rings.append([bm.verts.new((x, y, z)) for x, z in pts])
    faces = [bm.faces.new(rings[0]), bm.faces.new(list(reversed(rings[-1])))]
    for a, b in zip(rings, rings[1:]):
        for i in range(8):
            j = (i + 1) % 8
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for f in faces:
        f.material_index = mi


def blades(bm, hub, radius, chord, thick, count, axis, mi, start=0.0, off=(0, 0, 0)):
    """`count` flat blades from `hub`, in the plane normal to `axis` ('z' or 'x')."""
    for k in range(count):
        a = start + 2 * math.pi * k / count
        r = bmesh.ops.create_cube(bm, size=1.0)
        for v in r["verts"]:
            # blade along local +u, chord along v, thickness along the axis
            u = (v.co.x + 0.5) * radius
            w = v.co.y * chord
            t = v.co.z * thick
            if axis == "z":
                p = Vector((u * math.cos(a) - w * math.sin(a), u * math.sin(a) + w * math.cos(a), t))
            else:
                p = Vector((t, u * math.cos(a) - w * math.sin(a), u * math.sin(a) + w * math.cos(a)))
            v.co = p + Vector(hub) - Vector(off)
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.material_index = mi


def build():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for d in list(coll):
            coll.remove(d)
    order = list(PALETTE)
    mats = [material("heli_" + k, PALETTE[k], 0.5 if k in ("metal", "glass") else 0.85,
                     0.4 if k == "metal" else 0.0) for k in order]

    def mi(k):
        return order.index(k)

    bm = bmesh.new()
    fuselage(bm, mi("tan"))
    # stepped tandem canopy: gunner low in front, pilot higher behind
    gunner = [(6.95, 1.95), (6.35, 2.38), (5.0, 2.45), (4.95, 1.95)]
    pilot = [(5.0, 2.45), (4.6, 2.78), (3.3, 2.85), (3.25, 2.3), (4.95, 2.3)]
    for prof, hw in ((gunner, 0.62), (pilot, 0.70)):
        prism_x(bm, prof, -hw, hw, mi("glass"))
    # engine nacelles high on each side, with dark exhausts
    for s in (-1, 1):
        cyl(bm, (s * 1.0, -1.4, 2.65), 0.36, 0.36, 3.0, "y", mi("tan"), 10)
        cyl(bm, (s * 1.0, -1.75, 2.65), 0.26, 0.30, 0.36, "y", mi("metal"), 10)
        box(bm, (s * 0.5 - 0.3, -0.5, 2.5), (s * 0.5 + 0.3, 1.0, 2.75), mi("tan_dark"))
    # mast and hub fairing
    cyl(bm, (0, MAST.y, 2.75), 0.22, 0.18, MAST.z - 2.75, "z", mi("metal"), 10)
    # stub wings with a rocket pod (inner) and a missile rack (outer) under each
    for s in (-1, 1):
        x0, x1 = sorted((s * 0.75, s * 2.45))
        box(bm, (x0, 0.15, 1.72), (x1, 1.25, 1.86), mi("tan"))
        box(bm, (s * 1.35 - 0.05, 0.5, 1.45), (s * 1.35 + 0.05, 0.9, 1.72), mi("metal"))
        cyl(bm, (s * 1.35, -0.25, 1.22), 0.23, 0.23, 1.7, "y", mi("tan_dark"), 10)
        box(bm, (s * 2.15 - 0.22, -0.1, 1.2), (s * 2.15 + 0.22, 1.35, 1.6), mi("metal"))
    # main gear: wheels on struts under the cockpit, and the tailwheel
    for s in (-1, 1):
        x0, x1 = sorted((s * 1.05, s * 1.25))
        cyl(bm, (min(x0, x1), 3.2, 0.32), 0.32, 0.32, 0.2, "x", mi("tyre"), 12)
        box(bm, (s * 0.85 - 0.05, 3.1, 0.32), (s * 1.08 + 0.05, 3.3, 0.95), mi("metal"))
    cyl(bm, (-0.05, -7.7, 0.16), 0.16, 0.16, 0.1, "x", mi("tyre"), 10)
    ventral = [(-7.2, 2.05), (-8.1, 2.05), (-7.85, 0.95), (-7.5, 0.95)]  # carries the tailwheel
    prism_x(bm, ventral, -0.07, 0.07, mi("tan"))
    box(bm, (-0.04, -7.75, 0.16), (0.04, -7.65, 1.0), mi("metal"))
    # swept fin and the horizontal stabiliser
    fin = [(-7.35, 2.2), (-8.0, 4.0), (-8.6, 4.0), (-8.75, 2.2)]
    prism_x(bm, fin, -0.08, 0.08, mi("tan"))
    box(bm, (-1.7, -8.65, 2.08), (1.7, -8.0, 2.18), mi("tan"))
    cyl(bm, (TAIL_HUB.x + 0.02, TAIL_HUB.y, TAIL_HUB.z), 0.12, 0.12, 0.26, "x", mi("metal"), 8)
    body = new_obj("Body", bm, mats)

    bm = bmesh.new()  # chin gun: turret and barrel, aims at the kaiju
    box(bm, (-0.22, 6.55, 0.72), (0.22, 7.0, 1.0), mi("metal"), off=GUN)
    cyl(bm, (0, 6.9, 0.84), 0.06, 0.05, 1.5, "y", mi("metal"), 8, off=GUN)
    new_obj("ChinGun", bm, mats, parent=body, origin=GUN)

    bm = bmesh.new()
    cyl(bm, MAST - Vector((0, 0, 0.12)), 0.42, 0.34, 0.24, "z", mi("metal"), 12, off=MAST)
    blades(bm, MAST, ROTOR_R, 0.53, 0.08, 4, "z", mi("rotor"), math.pi / 4, off=MAST)
    new_obj("MainRotor", bm, mats, parent=body, origin=MAST)

    bm = bmesh.new()
    cyl(bm, TAIL_HUB - Vector((0.06, 0, 0)), 0.1, 0.1, 0.12, "x", mi("metal"), 8, off=TAIL_HUB)
    blades(bm, TAIL_HUB, TAIL_R, 0.25, 0.05, 4, "x", mi("rotor"), math.pi / 4, off=TAIL_HUB)
    new_obj("TailRotor", bm, mats, parent=body, origin=TAIL_HUB)

    body.rotation_euler = (0.0, 0.0, math.pi)  # face -Y (glTF front, voxelize convention)
    return body


def export(blend_path, glb_path):
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True,
                              export_yup=True)


if __name__ == "__main__":
    build()
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
        if len(args) >= 2:
            export(args[0], args[1])
