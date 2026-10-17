"""City landmarks for Kaiju Incremental, modelled from code in Blender (no reference traced, no
generator, no third-party asset). 1 Blender unit = 1 sim unit (one floor); Z up, the front faces -Y.
Exports one GLB per landmark; tools/landmarks/bake.py turns its voxel shell into game data.
    blender -b --factory-startup --python assets/source/landmarks/build_landmarks.py -- <out_dir> [ids...]
"""
import math
import os
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1]
ONLY = sys.argv[sys.argv.index("--") + 2:]
_mats = {}


def lin(hexstr):
    c = [int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]


def mat(hexstr):
    if hexstr not in _mats:
        m = bpy.data.materials.new(hexstr)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = lin(hexstr) + [1.0]
        _mats[hexstr] = m
    return _mats[hexstr]


def _finish(obj, colour):
    obj.data.materials.append(mat(colour))
    return obj


def box(c, s, colour, rz=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c, rotation=(0, 0, rz))
    o = bpy.context.object
    o.scale = s
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, colour)


def cyl(c, r, depth, colour, verts=40, rot=(0, 0, 0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=c, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=c, rotation=rot)
    return _finish(bpy.context.object, colour)


def ellipse_ring(cz, rx, ry, depth, colour, verts=64):
    """Solid elliptic disc (a cylinder scaled)."""
    o = cyl((0, 0, cz), 1.0, depth, colour, verts)
    o.scale = (rx, ry, 1)
    bpy.ops.object.transform_apply(scale=True)
    return o


def prism(x0, x1, y0, y1, z0, apex, colour):
    """Gable: a triangular prism along y, base x0..x1 at z0, ridge at height apex."""
    xm = (x0 + x1) / 2
    v = [(x0, y0, z0), (x1, y0, z0), (xm, y0, apex), (x0, y1, z0), (x1, y1, z0), (xm, y1, apex)]
    f = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    me = bpy.data.meshes.new("prism")
    me.from_pydata(v, [], f)
    o = bpy.data.objects.new("prism", me)
    bpy.context.scene.collection.objects.link(o)
    return _finish(o, colour)


def torus(c, R, r, colour, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(location=c, rotation=rot, major_radius=R, minor_radius=r,
                                     major_segments=72, minor_segments=8)
    return _finish(bpy.context.object, colour)


def beam(a, b, t, colour):
    """Square beam of thickness t from point a to point b."""
    import mathutils
    a, b = mathutils.Vector(a), mathutils.Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cube_add(size=1, location=(a + b) / 2)
    o = bpy.context.object
    o.scale = (t, t, d.length)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = mathutils.Vector((0, 0, 1)).rotation_difference(d.normalized())
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return _finish(o, colour)


# ---------------------------------------------------------------- the six concepts
CONCRETE = "c9c6bd"
STEEL = "8d949c"


def annulus(z0, z1, ro, ri, colour):
    """Elliptic ring wall from z0 to z1: outer half-axes ro, inner ri (a boolean cut)."""
    o = ellipse_ring((z0 + z1) / 2, ro[0], ro[1], z1 - z0, colour, 72)
    cut = ellipse_ring((z0 + z1) / 2, ri[0], ri[1], z1 - z0 + 1.0, colour, 72)
    m = o.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cut
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="cut")
    bpy.data.objects.remove(cut)
    return o


def stadium():
    """A: Thunderbowl - oval stadium: terraced red stands round a striped pitch, a cantilever
    roof ring on ribs, four floodlight masts."""
    RED, WHITE = "b33a2e", "e2ddd0"
    ellipse_ring(0.15, 13.6, 10.6, 0.3, "8a8478")                  # forecourt
    ellipse_ring(0.6, 8.0, 5.0, 1.2, "3f8f3a")                     # pitch (top at 1.2)
    for i in range(9):                                             # mowing stripes
        if i % 2:
            box((-7.0 + i * 1.75, 0, 1.22), (1.7, 9.0, 0.05), "4fa346")
    tiers = [((8.9, 5.9), (8.0, 5.0), 1.9, RED), ((9.8, 6.8), (8.9, 5.9), 2.6, "8f2c24"),
             ((10.7, 7.7), (9.8, 6.8), 3.3, RED), ((11.6, 8.6), (10.7, 7.7), 4.0, "8f2c24"),
             ((12.4, 9.4), (11.6, 8.6), 4.7, RED)]
    for ro, ri, top, col in tiers:                                 # terraces rise outward
        annulus(0.0, top, ro, ri, col)
    annulus(0.0, 5.4, (13.2, 10.2), (12.4, 9.4), CONCRETE)         # outer wall
    for i in range(36):                                            # wall piers, flush with the wall top
        a = i / 36 * math.tau
        if abs(math.sin(a) + 1.0) < 0.06:
            continue                                               # none behind the banner
        box((13.25 * math.cos(a), 10.25 * math.sin(a), 2.7), (0.6, 0.6, 5.4), "efeae0", rz=a)
    annulus(6.2, 6.7, (13.6, 10.6), (11.4, 8.4), WHITE)            # cantilever roof ring
    for i in range(28):                                            # ribs, tucked under the ring
        a = i / 28 * math.tau
        beam((13.3 * math.cos(a), 10.3 * math.sin(a), 5.4), (12.4 * math.cos(a), 9.4 * math.sin(a), 6.2), 0.4, "f4f1e8")
    for sx in (-1, 1):                                             # floodlight masts
        for sy in (-1, 1):
            x, y = sx * 12.0, sy * 9.2
            rz = math.atan2(sy, sx) + math.pi / 2
            beam((x, y, 0), (x, y, 11), 0.6, STEEL)
            box((x, y, 11.4), (2.6, 0.5, 1.4), "2a2a2a", rz=rz)
            box((x - sx * 0.3, y - sy * 0.3, 11.4), (2.2, 0.2, 1.0), "fff1a8", rz=rz)
    box((0, -10.5, 3.2), (6, 0.5, 2.0), "f2c230")                  # banner over the gate
    box((0, -10.4, 1.0), (3, 0.6, 2.0), "2a2f3a")                  # gate


def gate():
    """B: Red Lantern Gate - a temple gate: red pillars, a wide centre passage, three tiered roofs
    with upturned corners, stone steps front and back, two free-standing lanterns."""
    RED, ROOF, GOLD, STONE = "c2271f", "1f5a4e", "e3b23c", "8a8478"
    box((0, 0, 0.6), (16, 7, 1.2), STONE)                          # plinth
    box((0, 0, 1.3), (14.6, 5.8, 0.4), "a39c8e")                   # upper step (overlaps, no seam)
    for sy in (-1, 1):                                             # steps at the centre bay
        for k in range(3):
            box((0, sy * (3.9 + 0.45 * k), 0.6 - 0.2 * k), (5.0, 0.9, 1.2 - 0.4 * k), "a39c8e")
    for x in (-6.6, -3.0, 3.0, 6.6):                               # pillars: tall, wide centre bay
        for y in (-2, 2):
            cyl((x, y, 4.75), 0.55, 6.5, RED, 20)
            cyl((x, y, 1.75), 0.8, 0.5, "3a332c", 20)
    box((0, 0, 8.1), (15, 5.6, 0.7), RED)                          # lintel
    box((0, -2.85, 8.1), (14.6, 0.2, 0.5), GOLD)                   # gold band
    box((0, -3.0, 7.0), (3.2, 0.3, 1.5), "141414")                 # name board over the passage
    box((0, -3.15, 7.0), (2.6, 0.1, 1.0), GOLD)
    for sx in (-1, 1):                                             # red lanterns hung at the lintel's front
        box((sx * 2.05, -3.1, 7.55), (0.15, 0.15, 0.4), "3a332c")
        box((sx * 2.05, -3.1, 6.6), (0.8, 0.9, 1.4), "d8362a")
        box((sx * 2.05, -3.1, 7.35), (0.6, 0.7, 0.15), GOLD)
        box((sx * 2.05, -3.1, 5.85), (0.6, 0.7, 0.15), GOLD)
    # three roofs, each a flared hip with gold-tipped upturned corners, a red storey between
    roofs = [(8.5, 8.6, 1.5), (10.9, 6.4, 1.3), (13.0, 4.3, 1.4)]
    for k, (z, half, hgt) in enumerate(roofs):
        o = cyl((0, 0, z + hgt / 2), half * 1.41, hgt, ROOF, 4, rot=(0, 0, math.pi / 4), r2=half * 0.55)
        bpy.ops.object.transform_apply(rotation=True)
        o.scale = (1.0, 0.55, 1.0)
        bpy.ops.object.transform_apply(scale=True)
        for sx in (-1, 1):
            for sy in (-1, 1):
                box((sx * (half - 0.3), sy * (half * 0.55 - 0.3), z + 0.5), (1.2, 1.2, 1.0), ROOF)
                box((sx * (half + 0.1), sy * (half * 0.55 + 0.1), z + 1.1), (0.7, 0.7, 0.7), GOLD)
        if k < 2:
            top = z + hgt
            nxt = roofs[k + 1][0]
            box((0, 0, (top - 0.3 + nxt + 0.2) / 2), (half * 1.05, 3.4, nxt + 0.5 - top), RED)
    box((0, 0, 14.6), (5.2, 0.6, 0.6), GOLD)                       # ridge
    for sx in (-1, 1):                                             # ridge ornaments
        box((sx * 2.8, 0, 15.2), (0.7, 0.7, 1.2), GOLD)
    for sx in (-1, 1):                                             # free-standing stone lanterns
        x, y = sx * 5.0, -6.6
        box((x, y, 0.3), (1.4, 1.4, 0.6), "6f6a60")
        box((x, y, 1.6), (0.6, 0.6, 2.0), "6f6a60")
        box((x, y, 3.2), (1.3, 1.3, 1.2), "d8362a")                # red lantern body
        box((x, y, 3.2), (1.4, 1.4, 0.2), GOLD)                    # gold band
        box((x, y, 4.0), (1.8, 1.8, 0.4), "3a332c")
        box((x, y, 4.4), (0.8, 0.8, 0.4), "3a332c")


def clock_hall():
    """C: Civic Clock Hall - stone hall with a pedimented colonnade, a hipped copper roof and a
    clock tower with a face on every side."""
    STONE = "d8ccb2"
    box((0, 0, 0.5), (18, 11, 1.0), "9c9384")                     # plinth
    for k in range(3):                                             # front steps
        box((0, -5.9 - 0.4 * k, 0.5 - 0.17 * k), (9.0, 0.8, 1.0 - 0.33 * k), "b0a796")
    box((0, 0, 3.5), (16, 9, 5.0), STONE)                          # main hall
    for x in [-7 + i * 1.75 for i in range(9)]:                    # colonnade
        cyl((x, -5.0, 3.2), 0.38, 4.4, "efe7d4", 16)
    box((0, -4.9, 5.7), (16.2, 1.6, 0.6), "efe7d4")                # entablature (top at 6.0)
    prism(-6.4, 6.4, -5.6, -2.0, 5.95, 8.1, "4f8f7c")              # portico roof, gable to the front
    prism(-5.8, 5.8, -5.75, -5.55, 6.15, 7.8, "b9a684")            # shaded tympanum on the gable end
    for sx in (-1, 1):                                             # raking cornice along both slopes
        beam((sx * 6.5, -5.8, 5.95), (0, -5.8, 8.2), 0.3, "efe7d4")
    for sx in (-1, 1):                                             # side-wall windows
        for y in (-2.5, -0.5, 1.5, 3.5):
            for z in (2.3, 4.3):
                box((sx * 8.0, y, z), (0.1, 0.7, 1.1), "3a3f4a")
    for x in [-6 + i * 1.5 for i in range(9)]:                    # windows
        for z in (2.3, 4.3):
            box((x, -4.45, z), (0.7, 0.1, 1.1), "3a3f4a")
    box((0, 0, 6.4), (16.4, 9.4, 0.8), "b7aa90")                   # cornice
    o = cyl((0, 0, 7.5), 1.41, 1.4, "4f8f7c", 4, rot=(0, 0, math.pi / 4), r2=0.5)  # hipped roof
    bpy.ops.object.transform_apply(rotation=True)
    o.scale = (7.8, 4.4, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    # clock tower
    box((0, 1.0, 10.5), (4.2, 4.2, 7.0), STONE)
    box((0, 1.0, 14.2), (4.8, 4.8, 0.5), "b7aa90")
    faces = [((0, -1.15), (math.pi / 2, 0, 0), (0, -1)), ((0, 3.15), (math.pi / 2, 0, 0), (0, 1)),
             ((-2.15, 1.0), (0, math.pi / 2, 0), (-1, 0)), ((2.15, 1.0), (0, math.pi / 2, 0), (1, 0))]
    for (dx, dy), rot, (nx, ny) in faces:                          # four faces, all showing 3:00
        cyl((dx, dy, 12.0), 1.45, 0.2, "2b2a28", 32, rot=rot)          # dark dial ring
        cyl((dx + nx * 0.05, dy + ny * 0.05, 12.0), 1.25, 0.25, "f4efe0", 32, rot=rot)
        hx, hy = dx + nx * 0.2, dy + ny * 0.2
        rx, ry = -ny, nx                                           # the viewer's right on this face
        for side, length in ((1, 1.0), (-1, 0.7)):                 # 10:10, pivot at the centre
            beam((hx, hy, 12.0), (hx + rx * side * 0.87 * length, hy + ry * side * 0.87 * length,
                                   12.0 + 0.5 * length), 0.2, "1a1a1a")
    box((0, 1.0, 15.2), (3.6, 3.6, 1.6), "efe7d4")                 # belfry
    for nx, ny in ((0, -1), (0, 1), (-1, 0), (1, 0)):              # dark louvred openings
        for k in (-0.75, 0.75):
            ox, oy = (k, 1.0 + ny * 1.85) if ny else (nx * 1.85, 1.0 + k)
            box((ox, oy, 15.1), (0.8 if ny else 0.25, 0.25 if ny else 0.8, 1.1), "2a2826")
    cyl((0, 1.0, 17.5), 2.6, 3.0, "4f8f7c", 4, rot=(0, 0, math.pi / 4), r2=0.2)  # spire
    cyl((0, 1.0, 19.3), 0.12, 0.8, "e3b23c", 8)


def wheel():
    """D: Sky Wheel - an observation wheel: a polygon rim of straight segments on two A-frames,
    a drum hub, level capsules mounted outside the rim."""
    R, N = 10.0, 32
    hz = R + 4.6
    box((0, 0, 0.4), (14, 8, 0.8), "8a8478")                       # base
    box((0, 0, 1.4), (5.0, 2.4, 1.2), "f2c230")                    # boarding hall under the rim
    for sy in (-1, 1):                                             # two A-frames
        for sx in (-1, 1):
            beam((sx * 5.5, sy * 3.0, 0.8), (0, sy * 1.0, hz), 0.9, "e8e6e0")
    cyl((0, 0, hz), 1.0, 2.0, STEEL, 24, rot=(math.pi / 2, 0, 0))  # hub drum
    cyl((0, 0, hz), 0.35, 2.8, "5a5f66", 12, rot=(math.pi / 2, 0, 0))  # axle
    pts = [(R * math.cos(i / N * math.tau), hz + R * math.sin(i / N * math.tau)) for i in range(N)]
    for sy in (-0.6, 0.6):
        for i in range(N):                                         # rim: straight segments
            (x0, z0), (x1, z1) = pts[i], pts[(i + 1) % N]
            beam((x0, sy, z0), (x1, sy, z1), 0.5, "e8e6e0")
        for i in range(0, N, 2):                                   # spokes
            beam((0, sy, hz), (pts[i][0], sy, pts[i][1]), 0.2, "c9c6bd")
    cols = ["e2463b", "2f8fd8", "f2c230", "3fb36a"]
    for i in range(16):                                            # capsules outside the rim, level
        a = (i + 0.5) / 16 * math.tau
        cx, cz = (R + 1.35) * math.cos(a), hz + (R + 1.35) * math.sin(a)
        beam((R * math.cos(a), 0, hz + R * math.sin(a)), (cx, 0, cz), 0.25, "c9c6bd")
        box((cx, 0, cz), (1.2, 1.5, 1.1), cols[i % 4])
        box((cx, 0, cz + 0.1), (1.25, 1.1, 0.45), "a9d6ff")        # window band


def spire():
    """E: Signal Spire - broadcast tower: a shaft tapering in clean rings, three buttress legs,
    a glass pod, a banded antenna mast."""
    box((0, 0, 0.4), (10, 10, 0.8), "8a8478")
    for k in range(6):                                             # shaft in six constant rings
        r = 1.75 - k * 0.1
        cyl((0, 0, 0.8 + k * 3.65 + 1.825), r, 3.65, CONCRETE, 32)
        if k:
            cyl((0, 0, 0.8 + k * 3.65), r + 0.12, 0.25, "b5b1a7", 32)  # ring joint
    for i in range(3):                                             # buttress legs
        a = i / 3 * math.tau + math.pi / 2
        beam((4.2 * math.cos(a), 4.2 * math.sin(a), 0.8), (0.9 * math.cos(a), 0.9 * math.sin(a), 9.0), 1.2, CONCRETE)
    cyl((0, 0, 22.6), 1.3, 1.2, "8d949c", 32, r2=4.0)              # pod underside
    cyl((0, 0, 24.0), 4.2, 1.8, "3b6f99", 40)                      # glass ring
    for i in range(16):                                            # mullions
        a = i / 16 * math.tau
        box((4.15 * math.cos(a), 4.15 * math.sin(a), 24.0), (0.3, 0.3, 1.8), "e8e6e0", rz=a)
    cyl((0, 0, 25.2), 4.4, 0.6, "e8e6e0", 40)                      # flat roof
    cyl((0, 0, 25.8), 3.0, 0.6, "e8e6e0", 40)
    cyl((0, 0, 26.8), 1.6, 1.4, "e8e6e0", 24)
    for k in range(10):                                            # red/white mast
        cyl((0, 0, 28.0 + k * 1.0), 0.55 - k * 0.03, 1.0, "d4322a" if k % 2 == 0 else "f2f2f2", 12)
    cyl((0, 0, 38.4), 0.2, 1.2, "d4322a", 8)
    box((0, 0, 39.1), (0.6, 0.6, 0.3), "ff3b2a")                   # beacon


def megatower():
    """F: Crown Megatower - glass tower stepping in every 3 floors, an open gold crown of points.
    Axis-aligned on purpose: rotated floors alias into ragged edges at 8 voxels per floor."""
    box((0, 0, 1.5), (16, 16, 3.0), "6c7480")                     # podium
    box((0, -8.05, 1.5), (10, 0.2, 2.2), "f2d38a")                 # lit lobby
    z, size = 3.0, 11.0
    steps = 14
    for k in range(steps):                                         # stepped glass floors (3 floors a step)
        rz = 0.0
        s = size - k * 0.32
        box((0, 0, z + 1.5), (s - 0.3, s - 0.3, 3.0), "1f3348", rz=rz)  # dark core: floor lines
        for f in range(3):                                         # one glass row per floor, dark seam 3 voxels
            box((0, 0, z + f * 0.9 + 0.42), (s, s, 0.55), "4a8cc0", rz=rz)
        box((0, 0, z + 2.8), (s, s, 0.4), "cfd7df", rz=rz)        # setback band every 3 floors
        z += 3.0
    rz = 0.0
    s = size - steps * 0.32
    box((0, 0, z + 0.2), (s - 0.6, s - 0.6, 0.4), "2a2f3a")          # dark open top
    for i in range(8):                                             # crown: 8 straight stepped points
        a = i / 8 * math.tau + math.pi / 8
        x, y = round(0.42 * s * math.cos(a) * 4) / 4, round(0.42 * s * math.sin(a) * 4) / 4
        box((x, y, z + 1.5), (0.75, 0.75, 3.0), "e3b23c")
        box((x, y, z + 3.6), (0.5, 0.5, 1.2), "e3b23c")
        box((x, y, z + 4.6), (0.25, 0.25, 0.8), "f2d38a")
    ro, ri = 0.45 * s + 0.5, 0.45 * s - 0.5
    annulus(z, z + 0.6, (ro, ro), (ri, ri), "e3b23c")              # crown band, open centre
    box((0, 0, z + 2.5), (1.0, 1.0, 5.0), "e3b23c")                # central spire, stepped
    box((0, 0, z + 6.0), (0.6, 0.6, 2.0), "e3b23c")
    box((0, 0, z + 7.75), (0.25, 0.25, 1.5), "f2d38a")


ALL = {"stadium": stadium, "gate": gate, "clock_hall": clock_hall, "wheel": wheel,
       "spire": spire, "megatower": megatower}

for name, fn in ALL.items():
    if ONLY and name not in ONLY:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    fn()
    # merge so the GLB is one object; report height for the voxel bake
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    xs = [(o.matrix_world @ v.co).x for o in objs for v in o.data.vertices]
    ys = [(o.matrix_world @ v.co).y for o in objs for v in o.data.vertices]
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False)
    print(f"LANDMARK {name} h={max(zs) - min(zs):.2f} w={max(xs) - min(xs):.2f} d={max(ys) - min(ys):.2f} -> {path}")
