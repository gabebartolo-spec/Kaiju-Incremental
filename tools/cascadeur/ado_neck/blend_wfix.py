"""blend_wfix.py: young rig blend + WFIX weights (fbx_r12m.py's WFIX block, same vertex-order check) -> save as OUT.
WFIX=<npz> blender -b <in.blend> --python blend_wfix.py -- <out.blend>"""
import bpy, sys, os, numpy as np
out = sys.argv[sys.argv.index("--") + 1:][0]
mesh = bpy.data.objects["croc_mesh"]; me = mesh.data
z = np.load(os.environ["WFIX"]); G = [str(g) for g in z["groups"]]; WN = z["W"]
Vb = np.array([tuple(mesh.matrix_world @ v.co) for v in me.vertices]); Vf = z["V"]
assert len(Vb) == len(Vf), (len(Vb), len(Vf))
off = np.abs(Vb - Vf).max(); print("VERT ORDER max offset %.6f" % off); assert off < 1e-3 * np.abs(Vf).max()
old = {g.name for g in mesh.vertex_groups}
for g in mesh.vertex_groups: g.remove(list(range(len(me.vertices))))
for gname in G:
    if gname not in mesh.vertex_groups: mesh.vertex_groups.new(name=gname)
for i in range(len(WN)):
    for j in np.nonzero(WN[i] > 1e-4)[0]: mesh.vertex_groups[G[j]].add([i], float(WN[i, j]), "REPLACE")
print("groups before", len(old), "after", len(mesh.vertex_groups), "new", sorted(set(G) - old), "max infl", max(len(v.groups) for v in me.vertices))
bpy.ops.wm.save_as_mainfile(filepath=out, copy=True); print("SAVED", out)
