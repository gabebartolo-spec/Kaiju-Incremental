"""Builds the main battle tank (MBT) in Blender from code: hull, tracks, turret, barrel, MG.

    blender -b --python assets/source/vehicles/build_tank.py -- <out.blend> <out.glb>
    (or exec() it inside a live Blender through the MCP)

Blender axes: Z up, the tank faces +Y (glTF export turns that into -Z forward, the game's
facing). Ground is z = 0. Real-world metres, Abrams/Leopard-like: 9.8 m long with the gun,
3.7 m wide over the skirts, 2.4 m to the commander's cupola.

Objects (each its own mesh, parented so the turret can turn and the gun can elevate):
    Hull            origin on the ground at the centre
      Tracks        tracks, road wheels, idlers, sprockets (child of Hull)
      Turret        origin on the turret ring (z = 1.35), rotates about Z
        Barrel      origin on the trunnion, elevates about X; mantlet, tube, evacuator, brake
        CommanderMG origin on the cupola ring mount, rotates about Z
Our own model (no references traced, no generator). Low poly, flat colours, for voxelizing.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# -- dimensions (metres) ------------------------------------------------------------------
HULL_HALF_LEN = 3.95       # hull 7.9 m
HULL_HALF_W = 1.78         # upper hull / fenders
SKIRT_X = (1.78, 1.85)     # side skirt plate: overall width 3.7 m
DECK_Z = 1.35              # hull deck, turret ring
TRACK_X = (1.12, 1.74)     # track belt, each side
TRACK_T = 0.08             # belt thickness
WHEEL_R = 0.33
WHEEL_Y = [-2.7 + 0.9 * i for i in range(7)]
IDLER = (3.3, 0.62, 0.30)       # y, z, r (front)
SPROCKET = (-3.35, 0.64, 0.32)  # rear drive sprocket
TURRET_ROOF = 2.22
TRUNNION = (0.0, 1.95, 1.80)    # in hull space
GUN_TIP_Y = 5.85                # 9.8 m overall with the hull front at 3.95


def srgb(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]


def material(name, hexcol, rough=0.8, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    lin = srgb(hexcol)
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*lin, 1)
    return m


# Desert tan: warm, so it separates from the cool blue-hour concrete city.
PALETTE = {
    "tan": "#b89c6a",
    "tan_dark": "#8f774e",
    "track": "#2b2925",
    "wheel": "#4a4538",
    "barrel": "#a48a5c",
    "metal": "#3a3a38",
    "grille": "#5c4e36",
}


def new_obj(name, bm, mats, parent=None, origin=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    for m in mats:
        me.materials.append(m)
    if parent is not None:
        o.parent = parent
    o.location = origin
    return o


def tag(faces, mi):
    for f in faces:
        f.material_index = mi


def prism_x(bm, prof, x0, x1, mi=0, off=(0, 0, 0)):
    """Extrude a closed YZ polygon between x0 and x1."""
    ox, oy, oz = off
    a = [bm.verts.new((x0 - ox, y - oy, z - oz)) for y, z in prof]
    b = [bm.verts.new((x1 - ox, y - oy, z - oz)) for y, z in prof]
    fs = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    tag(fs, mi)


def prism_z(bm, foot, z0, z1, inset=0.0, mi=0, off=(0, 0, 0)):
    """Extrude a closed XY footprint from z0 to z1, the top shrunk toward its centre by inset."""
    ox, oy, oz = off
    cx = sum(p[0] for p in foot) / len(foot)
    cy = sum(p[1] for p in foot) / len(foot)
    top = []
    for x, y in foot:
        d = Vector((x - cx, y - cy))
        k = max(0.0, 1 - inset / max(d.length, 1e-6))
        top.append((cx + d.x * k, cy + d.y * k))
    a = [bm.verts.new((x - ox, y - oy, z0 - oz)) for x, y in foot]
    b = [bm.verts.new((x - ox, y - oy, z1 - oz)) for x, y in top]
    fs = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(foot)
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    tag(fs, mi)


def box(bm, lo, hi, mi=0, off=(0, 0, 0)):
    lo = Vector(lo) - Vector(off)
    hi = Vector(hi) - Vector(off)
    r = bmesh.ops.create_cube(bm, size=1.0)
    for v in r["verts"]:
        v.co = Vector((lo.x + (v.co.x + 0.5) * (hi.x - lo.x),
                       lo.y + (v.co.y + 0.5) * (hi.y - lo.y),
                       lo.z + (v.co.z + 0.5) * (hi.z - lo.z)))
    tag({f for v in r["verts"] for f in v.link_faces}, mi)


def cyl(bm, start, r1, r2, length, axis, mi=0, seg=12, off=(0, 0, 0)):
    """Cylinder or cone from start along +axis ('x', 'y' or 'z')."""
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2,
                              depth=length)
    rot = {"z": Matrix.Identity(3), "y": Matrix.Rotation(-math.pi / 2, 3, "X"),
           "x": Matrix.Rotation(math.pi / 2, 3, "Y")}[axis]
    c = Vector(start) - Vector(off)
    for v in r["verts"]:
        v.co = rot @ (v.co + Vector((0, 0, length / 2))) + c
    tag({f for v in r["verts"] for f in v.link_faces}, mi)


def convex_hull(pts):
    pts = sorted(set(pts))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def circle(cy, cz, r, n=20):
    return [(round(cy + r * math.cos(2 * math.pi * k / n), 4),
             round(cz + r * math.sin(2 * math.pi * k / n), 4)) for k in range(n)]


def track_outline(grow):
    """The belt's path: convex hull round the wheels, idler and sprocket, grown by `grow`."""
    pts = []
    for y in WHEEL_Y:
        pts += circle(y, TRACK_T + WHEEL_R, WHEEL_R + grow)
    pts += circle(IDLER[0], IDLER[1], IDLER[2] + grow)
    pts += circle(SPROCKET[0], SPROCKET[1], SPROCKET[2] + grow)
    return convex_hull(pts)


def belt(bm, x0, x1, mi):
    """A closed track belt: the outline ring between the inner and outer path."""
    outer = track_outline(TRACK_T)
    # inner path: each outer vertex pulled toward the inside along the vertex normal
    n = len(outer)
    inner = []
    for i in range(n):
        p, a, b = Vector(outer[i]), Vector(outer[i - 1]), Vector(outer[(i + 1) % n])
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x))  # hull is CCW, so this points inward
        inner.append(p + nrm * TRACK_T)
    o0 = [bm.verts.new((x0, y, z)) for y, z in outer]
    o1 = [bm.verts.new((x1, y, z)) for y, z in outer]
    i0 = [bm.verts.new((x0, y, z)) for y, z in inner]
    i1 = [bm.verts.new((x1, y, z)) for y, z in inner]
    fs = []
    for i in range(n):
        j = (i + 1) % n
        fs.append(bm.faces.new((o0[i], o0[j], o1[j], o1[i])))   # tread face
        fs.append(bm.faces.new((i0[i], i1[i], i1[j], i0[j])))   # inner face
        fs.append(bm.faces.new((o0[i], i0[i], i0[j], o0[j])))   # inboard side
        fs.append(bm.faces.new((o1[i], o1[j], i1[j], i1[i])))   # outboard side
    tag(fs, mi)


def build():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for d in list(coll):
            coll.remove(d)
    mats = {k: material("tank_" + k, v, 0.5 if k == "metal" else 0.85,
                        0.5 if k == "metal" else 0.0) for k, v in PALETTE.items()}
    order = list(PALETTE)

    def mi(k):
        return order.index(k)

    all_mats = [mats[k] for k in order]

    # ---- hull -------------------------------------------------------------------------------
    bm = bmesh.new()
    L = HULL_HALF_LEN
    # lower hull, between the tracks: belly plate with a sloped lower glacis and rear plate
    lower = [(-3.75, 0.45), (3.25, 0.45), (3.95, 1.0), (-3.95, 1.0), (-3.95, 0.7)]
    prism_x(bm, lower, -TRACK_X[0] + 0.02, TRACK_X[0] - 0.02, mi("tan_dark"))
    # upper hull over the tracks: long flat deck, shallow upper glacis to a blunt nose
    upper = [(-L, 1.0), (L, 1.0), (L, 1.08), (2.35, DECK_Z), (-L + 0.1, DECK_Z), (-L, 1.28)]
    prism_x(bm, upper, -HULL_HALF_W, HULL_HALF_W, mi("tan"))
    # side skirts: armour plates hanging over the upper run of the track
    for s in (-1, 1):
        x0, x1 = sorted((s * SKIRT_X[0], s * SKIRT_X[1]))
        skirt = [(-3.55, 0.62), (3.05, 0.62), (3.55, 1.0), (3.6, 1.1), (-3.65, 1.1)]
        prism_x(bm, skirt, x0, x1, mi("tan"))
        # dark seam lines between skirt panels
        for y in (-2.0, -0.4, 1.2):
            box(bm, (min(x0, x1) - 0.005 if s < 0 else x1 - 0.02, y, 0.64),
                (x0 + 0.02 if s < 0 else x1 + 0.005, y + 0.05, 1.08), mi("tan_dark"))
    # engine deck: grilles and exhaust at the rear
    box(bm, (-1.3, -3.7, DECK_Z), (1.3, -2.4, DECK_Z + 0.04), mi("grille"))
    box(bm, (-1.0, -3.97, 1.02), (1.0, -3.93, 1.25), mi("grille"))
    # driver's hatch on the front deck, headlight guards and tow points
    cyl(bm, (0, 2.85, DECK_Z - 0.05), 0.32, 0.30, 0.08, "z", mi("tan_dark"), 12)
    for s in (-1, 1):
        box(bm, (s * 1.45 - 0.12, 3.55, 1.12), (s * 1.45 + 0.12, 3.75, 1.24), mi("tan_dark"))
        box(bm, (s * 0.8 - 0.08, 3.9, 0.85), (s * 0.8 + 0.08, 4.02, 0.98), mi("metal"))
    hull = new_obj("Hull", bm, all_mats)

    # ---- tracks and running gear (child of the hull) ----------------------------------------
    bm = bmesh.new()
    for s in (-1, 1):
        x0, x1 = sorted((s * TRACK_X[0], s * TRACK_X[1]))
        belt(bm, x0, x1, mi("track"))
        wx0, wx1 = x0 + 0.03, x1 - 0.03
        for y in WHEEL_Y:
            cyl(bm, (wx0, y, TRACK_T + WHEEL_R), WHEEL_R, WHEEL_R, wx1 - wx0, "x", mi("wheel"), 16)
            hub_x = wx1 if s > 0 else wx0 - 0.04
            cyl(bm, (hub_x, y, TRACK_T + WHEEL_R), 0.12, 0.12, 0.04, "x", mi("metal"), 10)
        for (y, z, r) in (IDLER, SPROCKET):
            cyl(bm, (wx0, y, z), r, r, wx1 - wx0, "x", mi("wheel"), 16)
        # return rollers under the upper run
        for y in (-1.8, 0.0, 1.8):
            top = TRACK_T + 2 * WHEEL_R + 0.02
            cyl(bm, (wx0 + 0.1, y, top), 0.08, 0.08, wx1 - wx0 - 0.2, "x", mi("metal"), 8)
    tracks = new_obj("Tracks", bm, all_mats, parent=hull)

    # ---- turret (pivot on the ring) ---------------------------------------------------------
    ring = Vector((0.0, -0.1, DECK_Z))
    bm = bmesh.new()
    foot = [(-0.75, 1.95), (0.75, 1.95), (1.6, 1.15), (1.6, -1.55), (1.25, -2.45),
            (-1.25, -2.45), (-1.6, -1.55), (-1.6, 1.15)]
    foot = [(x, y + ring.y) for x, y in foot]
    prism_z(bm, foot, DECK_Z, TURRET_ROOF, inset=0.12, mi=mi("tan"), off=ring)
    # turret ring collar under the overhang
    cyl(bm, (0, ring.y, DECK_Z - 0.02), 1.1, 1.1, 0.08, "z", mi("tan_dark"), 20, off=ring)
    # bustle rack at the rear
    box(bm, (-1.3, -2.85 + ring.y, 1.55), (1.3, -2.45 + ring.y, 2.0), mi("tan_dark"), off=ring)
    # commander's cupola (right) and loader's hatch (left)
    cup = Vector((0.72, -0.55 + ring.y, TURRET_ROOF))
    cyl(bm, cup, 0.42, 0.38, 0.12, "z", mi("tan_dark"), 14, off=ring)
    cyl(bm, cup + Vector((0, 0, 0.12)), 0.32, 0.30, 0.06, "z", mi("tan"), 12, off=ring)
    cyl(bm, (-0.72, -0.7 + ring.y, TURRET_ROOF), 0.36, 0.34, 0.06, "z", mi("tan_dark"), 12, off=ring)
    # gunner's primary sight and the commander's independent sight
    box(bm, (-1.15, 0.9 + ring.y, TURRET_ROOF - 0.05), (-0.75, 1.45 + ring.y, TURRET_ROOF + 0.22),
        mi("tan_dark"), off=ring)
    box(bm, (-0.15, 0.55 + ring.y, TURRET_ROOF), (0.15, 0.85 + ring.y, TURRET_ROOF + 0.32),
        mi("metal"), off=ring)
    # smoke grenade dischargers on both cheeks
    for s in (-1, 1):
        box(bm, (s * 1.62 - 0.15, 0.6 + ring.y, 1.75), (s * 1.62 + 0.15, 1.05 + ring.y, 1.95),
            mi("metal"), off=ring)
    turret = new_obj("Turret", bm, all_mats, parent=hull, origin=ring)

    # ---- barrel (pivot on the trunnion) -------------------------------------------------------
    tr = Vector(TRUNNION)
    bm = bmesh.new()
    box(bm, (-0.5, tr.y - 0.1, tr.z - 0.3), (0.5, tr.y + 0.45, tr.z + 0.28), mi("tan_dark"), off=tr)
    y = tr.y + 0.45
    tube = GUN_TIP_Y - 0.5 - y
    cyl(bm, (0, y, tr.z), 0.16, 0.13, 0.5, "y", mi("barrel"), 12, off=tr)            # sleeve
    cyl(bm, (0, y + 0.5, tr.z), 0.11, 0.10, tube * 0.45, "y", mi("barrel"), 12, off=tr)
    cyl(bm, (0, y + 0.5 + tube * 0.45, tr.z), 0.15, 0.15, 0.45, "y", mi("barrel"), 12, off=tr)
    cyl(bm, (0, y + 0.95 + tube * 0.45, tr.z), 0.10, 0.09, tube * 0.55 - 0.45, "y",
        mi("barrel"), 12, off=tr)
    # muzzle brake: a squared block with side ports
    box(bm, (-0.17, GUN_TIP_Y - 0.5, tr.z - 0.13), (0.17, GUN_TIP_Y, tr.z + 0.13), mi("metal"), off=tr)
    box(bm, (-0.19, GUN_TIP_Y - 0.36, tr.z - 0.09), (0.19, GUN_TIP_Y - 0.26, tr.z + 0.09),
        mi("track"), off=tr)
    box(bm, (-0.19, GUN_TIP_Y - 0.18, tr.z - 0.09), (0.19, GUN_TIP_Y - 0.08, tr.z + 0.09),
        mi("track"), off=tr)
    barrel = new_obj("Barrel", bm, all_mats, parent=turret, origin=tr - ring)

    # ---- commander's machine gun on the cupola ----------------------------------------------
    mount = cup + Vector((0, 0, 0.18))
    bm = bmesh.new()
    cyl(bm, mount, 0.04, 0.04, 0.14, "z", mi("metal"), 8, off=mount)                 # pintle
    box(bm, (mount.x - 0.07, mount.y - 0.35, mount.z + 0.12), (mount.x + 0.07, mount.y + 0.15,
        mount.z + 0.26), mi("metal"), off=mount)                                       # receiver
    cyl(bm, (mount.x, mount.y + 0.15, mount.z + 0.19), 0.03, 0.03, 0.85, "y", mi("metal"), 8,
        off=mount)                                                                     # barrel
    box(bm, (mount.x + 0.07, mount.y - 0.2, mount.z + 0.1), (mount.x + 0.2, mount.y + 0.05,
        mount.z + 0.22), mi("tan_dark"), off=mount)                                    # ammo can
    new_obj("CommanderMG", bm, all_mats, parent=turret, origin=mount - ring)
    return hull


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
