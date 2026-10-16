"""Builds the adult reptilian kaiju by hand in Blender (no Tripo): a metaball sculpt remeshed into one
watertight hide, a separate lower jaw, jagged bone-ivory dorsal spines, keeled crocodile scutes and
armour plates, claws, teeth and deep-set eyes, coloured per vertex and baked to one texture.

    blender -b --python assets/source/kaiju/build_reptile.py -- <out.blend> <out.glb>

Real scale: about 100 m tall (1 Blender unit = 1 m). Facing -Y, Z up, feet on z = 0, arms held out
and a little down (a relaxed A-pose) so tools/blender/rig_voxel.py can trace the limbs; the mouth
is parted on a dark-red inside so rig_voxel finds the jaw. Colours are display (sRGB) values:
D-034 dark olive crocodile (deep muddy green, near-black scutes, duller grey-olive belly, ivory spines).
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector as V, noise
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = ARGS[0], ARGS[1]
RES = 0.5  # metaball polygonize step, m
REMESH = 0.38  # voxel remesh of the hide, m
TEX = 2048

# Palette (display sRGB), sampled against the approved Tripo olive (D-034).
OLIVE = V((0.19, 0.23, 0.12))
OLIVE_DARK = V((0.10, 0.12, 0.07))
SCUTE = V((0.07, 0.08, 0.055))
BELLY = V((0.36, 0.36, 0.26))
IVORY = V((0.80, 0.79, 0.67))  # neutral bone: rig_voxel cleans warm torso voxels as blemishes
HORN = V((0.21, 0.205, 0.16))
MOUTH = V((0.42, 0.07, 0.06))
EYE = V((0.72, 0.56, 0.12))

random.seed(7)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
K = 0.573  # an ellipsoid element of radius 1 reaches K * size at threshold 0.6, stiffness 2


# --- metaball sculpt ------------------------------------------------------------------------------

def family(name):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = RES
    mb.threshold = 0.6
    o = bpy.data.objects.new(name, mb)
    scene.collection.objects.link(o)
    return o


def frame(t, w_hint):
    t = t.normalized()
    s = w_hint - t * w_hint.dot(t)
    if s.length < 1e-4:
        s = V((0, 0, 1)) - t * t.z
    s.normalize()
    return Matrix((t, s, t.cross(s))).transposed().to_quaternion()


def el(o, c, axes, q=None, stiff=2.0, neg=False):
    e = o.data.elements.new(type="ELLIPSOID")
    e.co = c
    e.radius = 1.0
    e.size_x, e.size_y, e.size_z = [max(0.05, a) / K for a in axes]
    if q is not None:
        e.rotation = q
    e.stiffness = stiff
    e.use_negative = neg
    return e


def tube(o, pts, rads, w_hint=V((1, 0, 0)), dens=0.7, shrink=0.86):
    """Overlapping ellipsoids along a polyline; rads[i] = (semi-axis along w_hint, the other)."""
    for i in range(len(pts) - 1):
        a, b = V(pts[i]), V(pts[i + 1])
        ra, rb = rads[i], rads[i + 1]
        L = (b - a).length
        q = frame(b - a, w_hint)
        n = max(1, math.ceil(L / (min(ra + rb) * dens)))
        last = i == len(pts) - 2
        for k in range(n + (1 if last else 0)):
            f = k / n
            w = (ra[0] + (rb[0] - ra[0]) * f) * shrink
            h = (ra[1] + (rb[1] - ra[1]) * f) * shrink
            el(o, a.lerp(b, f), (max(L / n * 0.9, 0.55 * min(w, h)), w, h), q)


def mirror(fn):
    for s in (1, -1):
        fn(s)


body = family("Hide")
X = V((1, 0, 0))
Z = V((0, 0, 1))

# Torso: pelvis to shoulders, leaning ~28 deg forward.
tube(body, [(0, 12, 45), (0, 4, 56), (0, -3, 66), (0, -7, 74)],
     [(10.5, 12), (12, 15), (14.5, 15.5), (12.5, 12)])
el(body, V((0, -9, 61)), (11, 9, 12), frame(V((0, -0.45, 0.89)), X))  # chest keel / pecs
el(body, V((0, 2, 76)), (14, 7, 8), frame(V((0, -0.3, 0.95)), X))  # shoulder hump
el(body, V((0, 9, 50)), (10, 9, 10))  # hips / rump
# Neck: thick, muscular, rising forward to the skull.
tube(body, [(0, -6, 75), (0, -12, 83), (0, -18, 89)], [(11, 11.5), (10, 10.5), (9, 9.5)])
el(body, V((0, -13, 79)), (7, 7, 9), frame(V((0, -0.6, 0.8)), X))  # throat
mirror(lambda s: el(body, V((s * 5.5, -10, 82)), (3.5, 8, 4), frame(V((0, -0.6, 0.8)), X)))  # neck cords

# Skull: heavy, long, theropod-crocodilian; snout dips a little.
tube(body, [(0, -19, 91), (0, -27, 92), (0, -37, 90.3), (0, -45, 88.6), (0, -50, 88)],
     [(10, 7.8), (8.9, 7.4), (6.8, 5.2), (5.2, 3.8), (3.9, 2.9)], dens=0.6)
mirror(lambda s: el(body, V((s * 6.6, -22, 88.5)), (4.2, 6.5, 5)))  # jaw muscle (cheek)
mirror(lambda s: el(body, V((s * 5.4, -31.5, 95.7)), (2.7, 5.2, 1.9), stiff=3.5))  # heavy brow ridge
mirror(lambda s: el(body, V((s * 4.4, -40, 92.6)), (1.4, 4.5, 1.2), stiff=3.0))  # snout ridge
mirror(lambda s: el(body, V((s * 6.1, -31.2, 93.6)), (1.9, 1.9, 1.6), neg=True, stiff=3))  # eye socket
el(body, V((0, -24, 97)), (4.5, 5, 2), stiff=3)  # crown

# Arms: out and a little down, elbows back, heavy forearms, three-fingered hands.
def arm(s):
    tube(body, [(s * 9, -7, 71), (s * 18, -10, 70), (s * 26, -12, 68.3), (s * 34, -18, 67.0),
                (s * 38, -21, 66.4)],
         [(5.4, 6), (5.6, 5.8), (4.4, 4.6), (3.8, 3.8), (3.2, 2.6)], w_hint=Z)
    el(body, V((s * 12, -7, 72)), (6, 6, 5.5))  # deltoid
    el(body, V((s * 20, -12.5, 69.5)), (5, 3.6, 4.4), frame(V((s, -0.2, -0.1)), Z))  # biceps
    for k, (dy, dz) in enumerate(((-3.2, 0.6), (0, 0), (3.2, -0.6))):
        a = V((s * 38.5, -21 + dy * 0.6, 66.4 + dz))
        b = a + V((s * 5.2, -2.4 + dy * 0.5, -1.8))
        tube(body, [a, b], [(1.6, 1.5), (1.2, 1.1)], w_hint=Z)
mirror(arm)

# Legs: digitigrade, huge thighs, knee forward, heel raised, three forward toes.
def leg(s):
    tube(body, [(s * 10.5, 10, 46), (s * 13, 4, 36), (s * 15, -2, 27), (s * 15, 8, 18), (s * 14.5, 17, 9),
                (s * 14.5, 8, 3.2)],
         [(7.8, 11), (8, 10.5), (6.2, 6.5), (5.2, 5.4), (3.6, 3.8), (3.8, 3.2)])
    el(body, V((s * 12.5, 6, 40)), (7, 9, 10), frame(V((0, -0.5, -0.85)), X))  # quadriceps mass
    el(body, V((s * 15.5, 4, 21)), (4.4, 5.5, 7), frame(V((0, 0.6, -0.8)), X))  # calf
    el(body, V((s * 14.5, 4, 2.4)), (5, 7, 2.4))  # foot pad
    for k, ang in enumerate((-0.42, 0.0, 0.42)):
        d = V((math.sin(ang) * s, -math.cos(ang), 0))
        a = V((s * 14.5, 2, 2.2))
        tube(body, [a, a + d * 5, a + d * 9 + V((0, 0, -0.4))], [(2.2, 1.9), (1.8, 1.6), (1.3, 1.2)])
mirror(leg)

# Tail: long, heavy, sinking toward the ground as a counterweight.
tail_pts = [(0, 16, 44), (0, 30, 38), (0, 46, 30), (0, 62, 22), (0, 78, 15), (0, 94, 10.5), (0, 108, 8),
            (0, 120, 7)]
tail_r = [(11, 11.5), (9, 9.5), (7.2, 7.6), (5.6, 5.8), (4.3, 4.4), (3.2, 3.2), (2.2, 2.1), (1.0, 1.0)]
tube(body, tail_pts, tail_r)

jaw = family("JawMB")
tube(jaw, [(0, -19, 84.6), (0, -27, 82.6), (0, -36, 81.4), (0, -44, 81.3), (0, -47.5, 81.6)],
     [(7, 3.6), (6.2, 3.0), (4.8, 2.4), (3.3, 1.9), (2.1, 1.4)], dens=0.6)
mirror(lambda s: el(jaw, V((s * 5, -21, 84)), (2.6, 5, 3)))  # jaw angle

mouth = family("MouthMB")
el(mouth, V((0, -32, 86.0)), (4.2, 12, 1.0))  # palate
el(mouth, V((0, -30, 83.4)), (3.4, 10, 1.1))  # tongue


def to_mesh(o, name):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    me.name = name
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    bpy.data.objects.remove(o)
    return ob


def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def remesh(ob, size, smooth=4, bumps=0.0):
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = size
    sm = ob.modifiers.new("smooth", "SMOOTH")
    sm.factor, sm.iterations = 0.6, smooth
    if bumps:
        tex = bpy.data.textures.new("hide_bumps", "CLOUDS")
        tex.noise_scale = 2.2
        d = ob.modifiers.new("bumps", "DISPLACE")
        d.texture, d.strength, d.mid_level = tex, bumps, 0.5
    apply_mods(ob)


hide = to_mesh(body, "Kaiju")
remesh(hide, REMESH, bumps=0.35)
jawm = to_mesh(jaw, "Jaw")
remesh(jawm, REMESH * 0.8, bumps=0.2)
mouthm = to_mesh(mouth, "Mouth")
print("hide verts", len(hide.data.vertices), "jaw verts", len(jawm.data.vertices))

bvh_hide = BVHTree.FromObject(hide, bpy.context.evaluated_depsgraph_get())
bvh_jaw = BVHTree.FromObject(jawm, bpy.context.evaluated_depsgraph_get())


def hit(bvh, origin, direction):
    loc, nrm, _, _ = bvh.ray_cast(V(origin), V(direction).normalized())
    return (loc, nrm) if loc is not None else (None, None)


# --- details (bmesh, one colour per vertex) ---------------------------------------------------------

def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


details = bmesh.new()
detail_colour = []  # (BMVert, sRGB colour) for every detail vertex


def add_hull(bm, pts, colour):
    """Convex hull of pts into bm; colour(p) -> sRGB for each new vertex."""
    verts = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=verts)
    drop = {v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)}
    if drop:
        bmesh.ops.delete(bm, geom=list(drop), context="VERTS")
    for v in verts:
        if v.is_valid:
            detail_colour.append((v, colour(v.co)))


def blade(bm, base, up, back, side, h, w, t, tip_back, colour):
    """A leaf-shaped blade: thick root of half-width w along `back`, sharp edges, tip leaning back."""
    pts = []
    for sx in (-1, 1):
        for f in (-1, -0.4, 0.4, 1):
            pts.append(base + back * (w * f) + side * (t * sx * (1 - 0.35 * abs(f))) - up * (0.25 * h))
    pts += [base + back * (-w * 0.85) + up * (0.42 * h), base + back * (w * 0.9) + up * (0.5 * h),
            base + back * (-w * 0.35 + tip_back * 0.6) + up * (0.8 * h), base + back * tip_back + up * h]
    pts += [base + back * (tip_back * 0.3) + up * (0.35 * h) + side * (t * 0.6 * sx) for sx in (-1, 1)]
    add_hull(bm, pts, colour)


def spine_colour(base, up, h):
    def c(p):
        f = max(0.0, min(1.0, (p - base).dot(up) / h + 0.25))
        f = f ** 0.7
        return SCUTE.lerp(IVORY, min(1.0, f * 1.6))
    return c


def jagged_spine(p, n, h, outward=None):
    """One dorsal spine: a tall main blade plus a front and a rear prong, leaning back."""
    back = V((0, 1, 0)) - n * n.y
    back.normalize()
    up = (n + back * 0.3).normalized()
    back = (back - up * back.dot(up)).normalized()
    if outward is not None:
        up = (up + outward * 0.18).normalized()
    side = up.cross(back).normalized()
    col = spine_colour(p, up, h)
    blade(details, p, up, back, side, h, 0.42 * h, 0.16 * h, 0.28 * h, col)
    blade(details, p + back * (0.42 * h), up, back, side, 0.55 * h, 0.22 * h, 0.11 * h, 0.3 * h, col)
    blade(details, p - back * (0.36 * h), up, back, side, 0.48 * h, 0.2 * h, 0.1 * h, 0.12 * h, col)


def scute(p, n, size, along=V((0, 1, 0)), colour=SCUTE, keel=0.55):
    """A crocodile osteoderm: a rounded rectangular plate with a raised central keel."""
    a = along - n * along.dot(n)
    if a.length < 1e-3:
        a = V((0, 0, 1)) - n * n.z
    a.normalize()
    s = n.cross(a).normalized()
    pts = []
    for fa in (-1, 1):
        for fs in (-1, 1):
            pts.append(p + a * (1.15 * size * fa) + s * (0.95 * size * fs) - n * (0.35 * size))
            pts.append(p + a * (0.95 * size * fa) + s * (0.8 * size * fs) + n * (0.22 * size))
    pts += [p + a * (0.8 * size * fa) + n * (keel * size) for fa in (-1, 1)]
    add_hull(details, pts, lambda q: colour)


def spine_height(y):
    pts = [(-18, 4.5), (-10, 8.5), (-4, 13), (6, 14.5), (16, 12.5), (30, 10), (60, 6), (90, 3), (106, 1.5)]
    for (y0, h0), (y1, h1) in zip(pts, pts[1:]):
        if y0 <= y <= y1:
            return h0 + (h1 - h0) * (y - y0) / (y1 - y0)
    return 0.0


def top_hit(x, y):
    p, n = hit(bvh_hide, (x, y, 150), (0, 0, -1))
    return p, n


def walk(x_of, y0, y1, gap_of, phase=0.0):
    """Points on the top of the hide along a line over the back, spaced by distance along the
    surface (the leaning back is steep: equal steps in y would leave gaps on it)."""
    out, run, prev, nxt = [], 0.0, None, None
    y = y0
    while y < y1:
        p, n = top_hit(x_of(y), y)
        if p is not None:
            if prev is not None:
                run += (p - prev).length
            if nxt is None:
                nxt = gap_of(y) * phase
            if run >= nxt:
                out.append((y, p, n))
                nxt = run + gap_of(y)
            prev = p
        y += 0.3
    return out


# Dorsal spines: a centre row and two staggered side rows from the back of the skull down the tail.
gap = lambda y: max(2.4, 0.72 * spine_height(y))
for y, p, n in walk(lambda y: 0.0, -18, 106, gap):
    jagged_spine(p - n * 0.6, n, spine_height(y))
for s in (1, -1):
    xs = lambda y, s=s: s * (1.8 + 0.2 * spine_height(y))
    for y, p, n in walk(xs, -15, 96, gap, phase=0.5):
        if spine_height(y) * 0.58 > 0.9:
            jagged_spine(p - n * 0.4, n, spine_height(y) * 0.58, outward=V((s, 0, 0)))

# Keeled scutes in rows either side of the spines, along back and tail.
taper = lambda y: max(0.45, min(1.0, 1.0 - max(0.0, y - 30) / 120))
for xr, size, y0, y1 in ((5.0, 1.75, -12, 104), (8.4, 1.7, -6, 70), (11.6, 1.5, -2, 40)):
    for s in (1, -1):
        xf = lambda y, s=s, xr=xr: s * xr * max(0.25, min(1.0, 1.0 - max(0.0, y - 30) / 110))
        for y, p, n in walk(xf, y0, y1, lambda y, size=size: 2.9 * size * taper(y) / 1.75):
            if n.z > 0.15 or y < 12:
                scute(p, n, size * taper(y))


def plate_patch(centre, direction, rows, cols, step, size, along=V((0, 1, 0))):
    """Armour: a grid of scutes laid on the hide where rays from outside meet it."""
    d = V(direction).normalized()
    a = along - d * along.dot(d)
    a.normalize()
    s = d.cross(a).normalized()
    for i in range(rows):
        for j in range(cols):
            o = V(centre) + a * ((i - (rows - 1) / 2) * step) + s * ((j - (cols - 1) / 2) * step) - d * 30
            p, n = hit(bvh_hide, o, d)
            if p is not None:
                scute(p, n, size * (0.8 + 0.2 * random.random()), along=a)


for s in (1, -1):
    plate_patch((s * 12, -6, 74), (-s, 0.1, -0.5), 3, 3, 3.2, 1.5, along=V((s, 0, -0.3)))  # shoulder
    plate_patch((s * 16, 2, 42), (-s, -0.5, 0), 2, 3, 3.2, 1.3, along=V((0, -0.4, -0.9)))  # thigh
    plate_patch((s * 9, -12, 84), (-s, 0.2, 0), 4, 2, 3.0, 1.2, along=V((0, -0.6, 0.8)))  # neck side
    plate_patch((s * 9, 34, 36), (-s, 0, -0.2), 2, 5, 3.3, 1.3, along=V((0, 1, -0.4)))  # tail flank


def claw(base, direction, length, width, curl=V((0, 0, -1))):
    d = V(direction).normalized()
    side = d.cross(curl).normalized()
    up = side.cross(d).normalized()
    pts = []
    for k, f in enumerate((0.0, 0.35, 0.7, 1.0)):
        r = width * (1 - f) + 0.05
        c = base + d * (length * f) - up * (length * 0.35 * f * f)
        for ang in range(5):
            th = ang / 5 * 2 * math.pi
            pts.append(c + side * (math.cos(th) * r * 0.8) + up * (math.sin(th) * r))
    col = lambda p: HORN.lerp(IVORY, min(1.0, max(0.0, (p - base).dot(d) / length * 1.4)))
    # A curved claw is not convex: hull each segment pair.
    for k in range(3):
        add_hull(details, pts[k * 5:(k + 2) * 5], col)


for s in (1, -1):
    for k, ang in enumerate((-0.42, 0.0, 0.42)):  # toe claws
        d = V((math.sin(ang) * s, -math.cos(ang), 0))
        tip = V((s * 14.5, 2, 2.2)) + d * 9 + V((0, 0, -0.4))
        claw(tip - d * 1.2 + V((0, 0, 0.4)), d + V((0, 0, -0.25)), 4.2, 1.15)
    claw(V((s * 13.2, 12.5, 4.5)), V((-s * 0.2, 0.5, -0.8)), 2.6, 0.8)  # dewclaw
    for k, (dy, dz) in enumerate(((-3.2, 0.6), (0, 0), (3.2, -0.6))):  # hand claws
        a = V((s * 38.5, -21 + dy * 0.6, 66.4 + dz))
        b = a + V((s * 5.2, -2.4 + dy * 0.5, -1.8))
        claw(b - (b - a).normalized() * 0.6, (b - a) + V((0, 0, -1.5)), 4.0, 1.0)


def tooth(p, direction, length, width):
    d = V(direction).normalized()
    side = d.cross(V((0, 1, 0)))
    if side.length < 1e-3:
        side = V((1, 0, 0))
    side.normalize()
    fwd = d.cross(side).normalized()
    pts = [p + side * (width * math.cos(t)) + fwd * (width * 0.8 * math.sin(t)) - d * 0.8
           for t in [i / 6 * 2 * math.pi for i in range(6)]]
    pts.append(p + d * length)
    add_hull(details, pts, lambda q: IVORY)


def jaw_halfwidth(y):
    return max(1.4, 2.0 + (y + 48) * 0.17)


for s in (1, -1):
    y = -46.5
    while y < -24:
        x = s * jaw_halfwidth(y) * 0.78
        p, n = hit(bvh_hide, (x, y, 70), (0, 0, 1))  # underside of the upper jaw
        if p is not None and p.z < 89:
            big = 1.0 + (0.6 if -44 < y < -40 else 0.0)
            tooth(p, (s * 0.05, -0.08, -1), 2.3 * big, 0.55 * big)
        y += 2.2

jaw_details = bmesh.new()
for s in (1, -1):
    y = -45.8
    while y < -25:
        x = s * jaw_halfwidth(y) * 0.72
        loc, nrm, _, _ = bvh_jaw.ray_cast(V((x, y, 95)), V((0, 0, -1)))
        if loc is not None:
            big = 1.0 + (0.5 if -43 < y < -39 else 0.0)
            d = V((s * 0.05, -0.05, 1)).normalized()
            pts = [loc + V((math.cos(t) * 0.5 * big, math.sin(t) * 0.45 * big, -0.8))
                   for t in [i / 6 * 2 * math.pi for i in range(6)]] + [loc + d * 2.0 * big]
            vs = [jaw_details.verts.new(q) for q in pts]
            bmesh.ops.convex_hull(jaw_details, input=vs)
        y += 2.3

# Eyes: small, deep in the socket under the brow.
for s in (1, -1):
    c = V((s * 5.25, -31.0, 93.3))
    add_hull(details, [c + V((math.cos(a) * math.sin(b), math.sin(a) * math.sin(b), math.cos(b))) * 0.75
                       for a in [i / 8 * 2 * math.pi for i in range(8)] for b in (0.4, 1.2, 1.95, 2.7)],
             lambda q: EYE)


# --- hide colour ----------------------------------------------------------------------------------

def smooth01(x, a, b):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def hide_colour(p, n):
    c = OLIVE.copy()
    mott = noise.noise(p / 7.0) * 0.5 + noise.noise(p / 2.3) * 0.25
    c *= 0.92 + 0.35 * mott
    # Scales: darker seams between cells about 1.6 m across.
    dist, _ = noise.voronoi(p / 1.6, distance_metric="DISTANCE")
    if dist[1] - dist[0] < 0.14:
        c *= 0.62
    # Back and flanks darker toward the spines.
    c = c.lerp(OLIVE_DARK, 0.75 * smooth01(n.z, 0.35, 0.9) * smooth01(abs(p.x), 9, 0) if p.z > 30 else 0.0)
    # Belly: underside of neck, chest, belly and tail, grey-olive with transverse plates.
    torso_front = smooth01(-n.y, 0.25, 0.7) * smooth01(10 - abs(p.x), 0, 4) * (1.0 if 40 < p.z < 86 and p.y < 12 else 0.0)
    under = smooth01(-n.z, 0.3, 0.75) * (1.0 if (p.y > 14 or (p.y < -10 and p.z > 74)) else 0.0)
    jaw_under = smooth01(-n.z, 0.2, 0.7) * (1.0 if p.y < -16 and p.z > 78 else 0.0)
    b = max(torso_front, under, jaw_under)
    if b > 0:
        band = (p.z if p.y < 12 else p.y) / 2.4
        belly = BELLY * (0.72 if (band - math.floor(band)) < 0.16 else 1.0)
        belly *= 0.92 + 0.2 * mott
        c = c.lerp(belly, b)
    # Dark sockets round the eyes, dark lips.
    for s in (1, -1):
        e = (p - V((s * 5.6, -31.3, 93.4))).length
        if e < 3.0:
            c = c.lerp(SCUTE, smooth01(3.0 - e, 0, 1.4))
    return c


def colour_mesh(ob, fn):
    me = ob.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    flat = []
    for v in me.vertices:
        flat.extend(lin(fn(v.co, v.normal)) + (1.0,))
    attr.data.foreach_set("color", flat)


colour_mesh(hide, hide_colour)
colour_mesh(jawm, hide_colour)
colour_mesh(mouthm, lambda p, n: MOUTH * (0.8 + 0.3 * (noise.noise(p / 1.5) * 0.5 + 0.5)))


def bm_object(bm, name, colours):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    flat = []
    for i, v in enumerate(me.vertices):
        flat.extend(lin(colours(i, v.co)) + (1.0,))
    attr.data.foreach_set("color", flat)
    return ob


details.verts.index_update()
idx_col = {}
for v, c in detail_colour:
    if v.is_valid:
        idx_col[v.index] = c
bmesh.ops.recalc_face_normals(details, faces=details.faces[:])
det = bm_object(details, "Details", lambda i, p: idx_col.get(i, IVORY))
bmesh.ops.recalc_face_normals(jaw_details, faces=jaw_details.faces[:])
jdet = bm_object(jaw_details, "JawTeeth", lambda i, p: IVORY)


# --- join, unwrap, bake ---------------------------------------------------------------------------

def join(objs, name):
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs,
                                   selected_objects=objs):
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


kaiju = join([hide, det], "Kaiju")
jaw_ob = join([jawm, jdet, mouthm], "Jaw")
for ob in (kaiju, jaw_ob):
    for p in ob.data.polygons:
        p.use_smooth = True

# Feet on the ground.
low = min(min((ob.matrix_world @ v.co).z for v in ob.data.vertices) for ob in (kaiju, jaw_ob))
for ob in (kaiju, jaw_ob):
    ob.data.transform(Matrix.Translation((0, 0, -low)))

for ob in (kaiju, jaw_ob):
    ob.data.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = kaiju
for ob in (kaiju, jaw_ob):
    ob.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0015)
bpy.ops.object.mode_set(mode="OBJECT")

img = bpy.data.images.new("kaiju_reptile_skin", TEX, TEX, alpha=False)
img.colorspace_settings.name = "sRGB"


def material(bake):
    m = bpy.data.materials.new("ReptileSkinBake" if bake else "ReptileSkin")
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    if bake:
        attr = nt.nodes.new("ShaderNodeAttribute")
        attr.attribute_name = "Col"
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(attr.outputs["Color"], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    else:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.78
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    nt.nodes.active = tex
    return m


bake_mat = material(True)
for ob in (kaiju, jaw_ob):
    ob.data.materials.clear()
    ob.data.materials.append(bake_mat)
try:
    scene.render.engine = "CYCLES"
except TypeError as e:
    print(e)
scene.cycles.samples = 1
scene.cycles.device = "CPU"
scene.render.bake.margin = 6
with bpy.context.temp_override(active_object=kaiju, selected_objects=[kaiju, jaw_ob],
                               selected_editable_objects=[kaiju, jaw_ob]):
    bpy.ops.object.bake(type="EMIT")
img.pack()

final = material(False)
for ob in (kaiju, jaw_ob):
    ob.data.materials.clear()
    ob.data.materials.append(final)
bpy.data.materials.remove(bake_mat)
for ob in (kaiju, jaw_ob):  # baked into the texture; left in, glTF importers mix it over the texture
    ob.data.color_attributes.remove(ob.data.color_attributes["Col"])
jaw_ob.parent = kaiju

print("kaiju faces", len(kaiju.data.polygons), "jaw faces", len(jaw_ob.data.polygons))
lo = [min((ob.matrix_world @ v.co)[i] for ob in (kaiju, jaw_ob) for v in ob.data.vertices) for i in range(3)]
hi = [max((ob.matrix_world @ v.co)[i] for ob in (kaiju, jaw_ob) for v in ob.data.vertices) for i in range(3)]
print("bounds", [round(x, 2) for x in lo], [round(x, 2) for x in hi])
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False,
                          export_attributes=False)
print("wrote", OUT_BLEND, OUT_GLB)
