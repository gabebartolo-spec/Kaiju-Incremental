"""Bakes the jagged stone chunks the kaiju's body breaks into when he dies (DeathView; director
2026-10-27, D-323: "Jagged stone chunks", irregular broken rock in his hide's texture, many sizes;
round 1 only recoloured the cubes, the shape was the defect).

    blender -b --factory-startup --python tools/blender/death_chunks.py -- <out_dir> [seed]

Method: a Voronoi cell fracture, the way Blender's Cell Fracture add-on breaks a solid (as do
Unreal's Chaos fracture and Houdini's Voronoi Fracture): a chunk is the cell of one seed point, cut
by the plane halfway to each neighbouring seed (mathutils.geometry.points_in_planes, then a convex
hull, as Cell Fracture's fracture_cell_calc does). Stretching the neighbours along an axis gives a
splinter, squashing them a slab. A few chip planes then knock corners off, and every corner is
nudged a little (the noise-displaced low-poly rock trick), so the faces meet at varied angles and no
face is square to another. Each chunk is centred on its volume's middle with its longest side 1 (the
game scales it), flat shaded, and written as a plain OBJ (y up, no material: the game draws it with
his stone, scenes/death_stone.gdshader). Pure Blender (bmesh, mathutils), no add-ons; seeded, so a
seed always gives the same chunks. Prints one line per chunk: faces, triangles, extents.
"""
import math
import os
import random
import sys

import bmesh
from mathutils import Vector
from mathutils.geometry import points_in_planes

# One row per chunk: (neighbour seeds, stretch of the neighbours per axis, chip cuts). More
# neighbours give more faces; a stretch over 1 makes the cell long on that axis, under 1 flat.
PROFILES = [
    (16, (1.0, 1.0, 1.0), 3),  # a broken lump
    (18, (1.15, 0.9, 1.0), 4),  # a lump
    (14, (1.0, 1.0, 0.85), 2),  # a squat lump
    (16, (1.0, 0.5, 1.1), 3),  # a slab
    (15, (1.2, 0.42, 0.9), 2),  # a thin slab
    (14, (2.1, 0.8, 0.9), 3),  # a splinter
    (16, (1.8, 1.0, 0.7), 4),  # a wedge
    (18, (1.4, 0.7, 1.3), 3),  # a flake
]
# How far a corner is nudged (share of the chunk's longest side before it is scaled to 1).
NUDGE = 0.035
# How deep a chip cuts into the chunk (share of its depth along the chip's direction).
CHIP_DEPTH = (0.1, 0.24)


def sphere_dirs(n, rng):
    """n directions spread over the sphere (a jittered Fibonacci spiral), so the cell is closed."""
    out = []
    turn = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        y = 1.0 - 2.0 * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1.0 - y * y))
        a = turn * i + rng.uniform(-0.35, 0.35)
        d = Vector((math.cos(a) * r, y, math.sin(a) * r))
        d += Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2)))
        out.append(d.normalized())
    return out


def cell_planes(neighbours, stretch, rng):
    """The cell of the seed at the origin: the half-space short of halfway to each neighbour."""
    planes = []
    for d in sphere_dirs(neighbours, rng):
        half = rng.uniform(0.8, 1.25) / 2.0  # n.x <= half, before the stretch
        # The cell stretched by `stretch` (x' = S x): its plane is (n / S).x' <= half.
        m = Vector((d.x / stretch[0], d.y / stretch[1], d.z / stretch[2]))
        n = m.normalized()
        planes.append(Vector((n.x, n.y, n.z, -half / m.length)))
    # A far box that never cuts: it only keeps the solve bounded.
    for axis in range(3):
        for sign in (-1.0, 1.0):
            n = Vector((0.0, 0.0, 0.0))
            n[axis] = sign
            planes.append(Vector((n.x, n.y, n.z, -5.0)))
    return planes


def corners(planes):
    verts, _used = points_in_planes(planes)
    return verts


def chip(planes, verts, rng):
    """One more plane that knocks a corner off: across a random direction, a little in from the tip."""
    u = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
    hi = max(v.dot(u) for v in verts)
    lo = min(v.dot(u) for v in verts)
    cut = hi - rng.uniform(*CHIP_DEPTH) * (hi - lo)
    return planes + [Vector((u.x, u.y, u.z, -cut))]


def hull(verts):
    bm = bmesh.new()
    for co in verts:
        bm.verts.new(co)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    loose = [g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    # Coplanar triangles back into one face each: the cell's real faces.
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts, edges=bm.edges)
    return bm


def extents(bm):
    lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
    hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
    return lo, hi


def volume_centre(bm):
    """The middle of the solid (signed tetrahedra from the origin), so it tumbles about its mass."""
    total = 0.0
    acc = Vector((0.0, 0.0, 0.0))
    for f in bm.faces:
        a = f.verts[0].co
        for i in range(1, len(f.verts) - 1):
            b = f.verts[i].co
            c = f.verts[i + 1].co
            vol = a.dot(b.cross(c)) / 6.0
            total += vol
            acc += (a + b + c) * (vol / 4.0)
    return acc / total if abs(total) > 1e-9 else Vector((0.0, 0.0, 0.0))


def chunk(profile, rng):
    neighbours, stretch, chips = profile
    planes = cell_planes(neighbours, stretch, rng)
    verts = corners(planes)
    for _ in range(chips):
        planes = chip(planes, verts, rng)
        verts = corners(planes)
    bm = hull(verts)
    faces = len(bm.faces)
    lo, hi = extents(bm)
    size = max(hi - lo)
    for v in bm.verts:
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * NUDGE * size
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    centre = volume_centre(bm)
    for v in bm.verts:
        v.co -= centre
    lo, hi = extents(bm)
    scale = 1.0 / max(hi - lo)
    for v in bm.verts:
        v.co *= scale
    bm.normal_update()
    # Outward faces (a nudged hull is still star-shaped about its middle).
    flip = [f for f in bm.faces if f.normal.dot(f.calc_center_median()) < 0.0]
    if flip:
        bmesh.ops.reverse_faces(bm, faces=flip)
        bm.normal_update()
    return bm, faces


def uv_of(co, n):
    """A planar projection along the face's main axis (the game's shader does not read it)."""
    a = [abs(n.x), abs(n.y), abs(n.z)]
    if a[1] >= a[0] and a[1] >= a[2]:
        return co.x, co.z
    if a[0] >= a[2]:
        return co.z, co.y
    return co.x, co.y


def write_obj(bm, path, name):
    lines = ["# %s: a jagged stone chunk, tools/blender/death_chunks.py (ours, D-323)" % name, "o %s" % name]
    index = {}
    for i, v in enumerate(bm.verts):
        index[v] = i + 1
        lines.append("v %.5f %.5f %.5f" % (v.co.x, v.co.y, v.co.z))
    vt = 0
    faces = []
    for fi, f in enumerate(bm.faces):
        n = f.normal
        lines.append("vn %.5f %.5f %.5f" % (n.x, n.y, n.z))
        corner = []
        for v in f.verts:
            u, w = uv_of(v.co, n)
            lines.append("vt %.5f %.5f" % (u + 0.5, w + 0.5))
            vt += 1
            corner.append("%d/%d/%d" % (index[v], vt, fi + 1))
        faces.append("f " + " ".join(corner))
    lines.append("s off")
    lines.extend(faces)
    with open(path, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = args[0] if args else "assets/death"
    seed = int(args[1]) if len(args) > 1 else 323
    os.makedirs(out, exist_ok=True)
    rng = random.Random(seed)
    for i, profile in enumerate(PROFILES):
        bm, faces = chunk(profile, rng)
        lo, hi = extents(bm)
        name = "chunk_%d" % i
        write_obj(bm, os.path.join(out, name + ".obj"), name)
        ext = hi - lo
        print(
            "CHUNK %s faces %d tris %d verts %d extents %.2f %.2f %.2f"
            % (name, faces, len(bm.faces), len(bm.verts), ext.x, ext.y, ext.z)
        )
        bm.free()


main()
