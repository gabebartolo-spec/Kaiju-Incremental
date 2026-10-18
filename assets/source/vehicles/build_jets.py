"""Builds one of the four military jets (D-072) in Blender from code, for the D-042 army set.

    blender -b --python assets/source/vehicles/build_jets.py -- <jet> <out.blend> <out.glb>
    jet: interceptor | attacker | bomber | delta

Then tools/blender/vox_jet.py voxelizes it for the game (wings at half resolution).

Same conventions as assets/source/vehicles/build_tank.py and build_heli.py (whose helpers it
uses): Z up, real metres, laid out facing +Y with the gear up (in flight), then the Body root
turned 180 degrees so the finished model faces -Y (glTF front, voxelize convention). Desert
tan, flat colours. Our own designs (no references traced, no generator, no real liveries).
"""
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_tank import box, cyl, material, new_obj, prism_x, prism_z  # noqa: E402

PALETTE = {
    "tan": "#b89c6a",
    "tan_dark": "#8f774e",
    "glass": "#2e3b45",
    "metal": "#3a3a38",
    "ordnance": "#d6cfbb",
}
ORDER = list(PALETTE)


def mi(k):
    return ORDER.index(k)


def loft(bm, sections, m):
    """Eight-sided rings through (y, half width, bottom z, top z) sections, capped."""
    rings = []
    for y, hw, zb, zt in sections:
        h = zt - zb
        pts = [(0.55 * hw, zt), (hw, zt - 0.3 * h), (hw, zb + 0.35 * h), (0.55 * hw, zb),
               (-0.55 * hw, zb), (-hw, zb + 0.35 * h), (-hw, zt - 0.3 * h), (-0.55 * hw, zt)]
        rings.append([bm.verts.new((x, y, z)) for x, z in pts])
    faces = [bm.faces.new(rings[0]), bm.faces.new(list(reversed(rings[-1])))]
    for a, b in zip(rings, rings[1:]):
        for i in range(8):
            j = (i + 1) % 8
            faces.append(bm.faces.new((a[i], a[j], b[j], b[i])))
    for f in faces:
        f.material_index = m


# Flying surfaces go in their own mesh (Wings), voxelized at half resolution so every
# stair step along a swept edge is two voxels long (vox_jet.py).
WBM = None


def wings(bm, right, z0, z1, m):
    """A pair of flat surfaces: `right` is the +X footprint [(x, y)...], mirrored to -X."""
    bm = WBM or bm
    prism_z(bm, right, z0, z1, mi=m)
    prism_z(bm, [(-x, y) for x, y in reversed(right)], z0, z1, mi=m)


def fin(bm, prof, x, hw, m, cant=0.0):
    """A vertical fin from a YZ profile at `x`, leaned outward by `cant` degrees."""
    bm = WBM or bm
    n0 = len(bm.verts)
    prism_x(bm, prof, x - hw, x + hw, m)
    if cant:
        bm.verts.ensure_lookup_table()
        vs = bm.verts[n0:]
        base = min(z for _, z in prof)
        a = math.radians(cant) * (1 if x > 0 else -1)
        bmesh.ops.rotate(bm, verts=vs, cent=(x, 0, base), matrix=Matrix.Rotation(a, 3, "Y"))


def store(bm, x, y_tail, z, r, length, m="ordnance"):
    """A bomb or missile along +Y from its tail, with a pylon up to the wing."""
    cyl(bm, (x, y_tail, z), r, r, length, "y", mi(m), 10)
    cyl(bm, (x, y_tail + length, z), r, 0.02, r * 2.2, "y", mi(m), 10)
    box(bm, (x - 0.05, y_tail + 0.3 * length, z + 0.6 * r), (x + 0.05, y_tail + 0.7 * length,
        z + r + 0.15), mi("metal"))


# Flying surfaces are at least 0.42 m thick (two voxels at the 2x grain): a one-voxel slab
# breaks into a saw-tooth comb along a swept edge. Stores hang a pylon's gap below the wing.
SKIN = 0.44
FIN_HW = 0.22


def interceptor(bm):
    """Fast twin-engine interceptor: long sharp nose, forward-swept wing, one tall fin,
    side intakes, missiles under the wing."""
    loft(bm, [(8.0, 0.36, 1.62, 2.30), (6.5, 0.56, 1.45, 2.55), (5.0, 0.72, 1.35, 2.72),
              (3.0, 1.10, 1.25, 2.60), (0.0, 1.45, 1.20, 2.45), (-4.0, 1.50, 1.20, 2.35),
              (-7.5, 1.35, 1.25, 2.25), (-9.0, 1.25, 1.30, 2.20)], mi("tan"))
    cyl(bm, (0, 8.0, 1.96), 0.36, 0.03, 1.6, "y", mi("tan_dark"), 10)
    prism_x(bm, [(6.0, 2.5), (5.0, 2.98), (3.4, 2.98), (2.5, 2.5)], -0.45, 0.45, mi("glass"))
    fin(bm, [(-4.4, 2.3), (-6.2, 5.4), (-7.4, 5.4), (-8.0, 2.3)], 0.0, FIN_HW, mi("tan_dark"))
    w0 = 1.62
    for s in (-1, 1):
        x0, x1 = sorted((s * 1.0, s * 1.7))
        box(bm, (x0, 0.8, 1.25), (x1, 3.6, 2.25), mi("tan"))
        box(bm, (x0 + 0.08, 3.55, 1.33), (x1 - 0.08, 3.65, 2.17), mi("metal"))
        cyl(bm, (s * 0.72, -9.8, 1.75), 0.5, 0.56, 0.85, "y", mi("metal"), 12)
        for x, tail in ((3.2, -2.7), (5.0, -1.4)):  # mid-chord under the wing
            store(bm, s * x, tail, w0 - 0.33, 0.14, 2.4)
    wings(bm, [(1.3, -0.6), (6.6, 1.6), (6.6, 0.2), (1.3, -5.0)], w0, w0 + SKIN, mi("tan"))
    wings(bm, [(1.2, -7.6), (3.7, -8.85), (3.7, -9.8), (1.2, -9.8)], 1.6, 1.6 + SKIN,
          mi("tan_dark"))


def attacker(bm):
    """Slow armoured ground-attack jet: wide slab-sided tub with bolted armour, one buried
    engine fed by a hump intake on its back, straight wing with big rocket pods and bombs
    under it, one swept fin, off-centre chin cannon."""
    cyl(bm, (0, 6.4, 1.68), 0.72, 0.3, 1.1, "y", mi("tan_dark"), 12)  # blunt armoured nose
    loft(bm, [(6.4, 1.10, 0.95, 2.40), (4.0, 1.35, 0.85, 2.60),
              (0.0, 1.38, 0.85, 2.65), (-3.5, 1.20, 0.95, 2.55), (-6.5, 0.70, 1.30, 2.35),
              (-7.8, 0.55, 1.45, 2.25)], mi("tan"))
    prism_x(bm, [(6.6, 2.2), (6.0, 2.85), (4.6, 2.9), (4.3, 2.4)], -0.55, 0.55, mi("glass"))
    for s in (-1, 1):  # armour plates on the cockpit sides
        x0, x1 = sorted((s * 1.15, s * 1.5))
        box(bm, (x0, 3.2, 1.1), (x1, 6.0, 2.35), mi("tan_dark"))
    box(bm, (-0.7, -1.0, 2.45), (0.7, 3.0, 3.25), mi("tan"))  # dorsal intake hump
    box(bm, (-0.6, 2.3, 2.6), (0.6, 3.05, 3.3), mi("metal"))  # intake mouth, seen from above
    cyl(bm, (0, -9.1, 1.85), 0.55, 0.6, 1.3, "y", mi("metal"), 12)
    box(bm, (0.2, 3.4, 0.6), (0.75, 6.4, 0.95), mi("metal"))  # cannon pod, off-centre
    cyl(bm, (0.48, 6.4, 0.78), 0.17, 0.17, 1.6, "y", mi("metal"), 8)
    w0 = 1.1
    wings(bm, [(1.2, 1.8), (7.8, 0.8), (7.8, -0.9), (1.2, -1.7)], w0, w0 + SKIN, mi("tan"))
    wings(bm, [(0.5, -6.2), (3.2, -7.3), (3.2, -8.2), (0.5, -8.1)], 1.55, 1.55 + SKIN,
          mi("tan_dark"))
    fin(bm, [(-4.6, 2.5), (-7.2, 4.7), (-8.2, 4.7), (-8.3, 2.5)], 0.0, FIN_HW, mi("tan"))
    for s in (-1, 1):
        cyl(bm, (s * 6.2, -2.0, w0 - 0.55), 0.36, 0.36, 3.0, "y", mi("tan_dark"), 10)
        cyl(bm, (s * 6.2, 1.0, w0 - 0.55), 0.36, 0.08, 0.6, "y", mi("ordnance"), 10)
        box(bm, (s * 6.2 - 0.05, -1.2, w0 - 0.22), (s * 6.2 + 0.05, 0.2, w0), mi("metal"))
        for x in (2.9, 4.5):
            store(bm, s * x, -1.0, w0 - 0.53, 0.33, 2.2)


def bomber(bm):
    """Heavy bomber: long pointed nose, swept leading edge with a straight trailing edge, four
    engines in two pods on its back, twin fins on the tailplane tips; bomb bay underneath."""
    loft(bm, [(15.0, 0.62, 3.40, 4.20), (12.0, 1.30, 2.90, 5.00), (8.0, 1.70, 2.70, 5.30),
              (-8.0, 1.70, 2.70, 5.30), (-13.0, 1.20, 3.20, 5.10), (-16.6, 0.60, 3.90, 4.90)],
         mi("tan"))
    cyl(bm, (0, 15.0, 3.8), 0.62, 0.04, 3.4, "y", mi("tan_dark"), 10)
    prism_x(bm, [(13.6, 4.75), (12.8, 5.45), (11.0, 5.55), (10.6, 5.2)], -0.9, 0.9, mi("glass"))
    box(bm, (-1.0, -6.0, 2.62), (1.0, 5.0, 2.75), mi("tan_dark"))
    wings(bm, [(1.6, 5.0), (17.0, -5.6), (17.0, -7.8), (1.6, -7.8)], 4.5, 5.0, mi("tan"))
    wings(bm, [(1.0, -12.4), (7.0, -15.4), (7.0, -16.4), (1.0, -16.4)], 4.7, 4.7 + SKIN,
          mi("tan_dark"))
    for s in (-1, 1):
        fin(bm, [(-13.6, 4.7), (-15.6, 8.6), (-16.8, 8.6), (-16.4, 4.7)], s * 7.0, FIN_HW,
            mi("tan"))
        x0, x1 = sorted((s * 0.35, s * 2.75))
        box(bm, (x0, -11.0, 4.9), (x1, -2.5, 6.3), mi("tan"))  # dorsal engine pod
        box(bm, (s * 1.55 - 0.04, -11.0, 4.9), (s * 1.55 + 0.04, -2.5, 6.35), mi("tan_dark"))
        for x in (0.95, 2.15):  # two engines per pod
            box(bm, (s * x - 0.5, -2.6, 5.0), (s * x + 0.5, -2.4, 6.2), mi("metal"))
            cyl(bm, (s * x, -11.6, 5.6), 0.42, 0.52, 0.65, "y", mi("metal"), 12)


def delta(bm):
    """Tailless delta-wing striker: no canards and no centre fin, a fin on each wingtip, a W
    trailing edge, chin intake, one engine, bombs under the wings."""
    loft(bm, [(6.2, 0.36, 1.60, 2.25), (4.5, 0.62, 1.40, 2.60), (2.5, 0.76, 1.30, 2.70),
              (0.0, 0.82, 1.30, 2.55), (-5.0, 0.76, 1.35, 2.45), (-7.2, 0.62, 1.45, 2.35)],
         mi("tan"))
    cyl(bm, (0, 6.2, 1.93), 0.36, 0.03, 1.6, "y", mi("tan_dark"), 10)
    prism_x(bm, [(4.6, 2.5), (3.8, 3.02), (2.2, 3.06), (1.6, 2.6)], -0.42, 0.42, mi("glass"))
    box(bm, (-0.62, 0.3, 0.88), (0.62, 3.0, 1.45), mi("tan"))
    box(bm, (-0.54, 2.95, 0.95), (0.54, 3.06, 1.38), mi("metal"))
    cyl(bm, (0, -8.3, 1.9), 0.5, 0.58, 1.15, "y", mi("metal"), 12)
    w0 = 1.6
    wings(bm, [(0.7, 2.2), (5.1, -5.3), (5.1, -7.0), (2.9, -5.4), (0.7, -7.1)], w0,
          w0 + SKIN, mi("tan"))  # W trailing edge: tips and root swept back, notch between
    for s in (-1, 1):
        fin(bm, [(-5.3, 1.3), (-6.5, 3.7), (-7.2, 3.7), (-7.0, 1.3)], s * 4.95, FIN_HW,
            mi("tan_dark"))
        for x in (1.9, 3.2):
            store(bm, s * x, -4.2, w0 - 0.5, 0.3, 2.4)


JETS = {"interceptor": interceptor, "attacker": attacker, "bomber": bomber, "delta": delta}


def build(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = [material("jet_" + k, PALETTE[k], 0.5 if k in ("metal", "glass") else 0.85,
                     0.4 if k == "metal" else 0.0) for k in ORDER]
    global WBM
    bm = bmesh.new()
    WBM = bmesh.new()
    JETS[name](bm)
    body = new_obj("Body", bm, mats)
    new_obj("Wings", WBM, mats, parent=body)
    WBM = None
    body.rotation_euler = (0.0, 0.0, math.pi)  # face -Y (glTF front, voxelize convention)
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in (body, *body.children) for v in o.data.vertices]
    dims = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
    return {"span_m": round(dims[0], 2), "length_m": round(dims[1], 2),
            "height_m": round(dims[2], 2)}


if __name__ == "__main__":
    jet, blend, glb = ARGS[:3]
    info = build(jet)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_apply=True,
                              export_yup=True)
    print("JET", jet, info)
