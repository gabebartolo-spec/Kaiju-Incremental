"""Game export of the approved croc adult3 rig (D-219 model; rig r11 = the r10 skeleton with r11 skin weights and eyelid
bones): the skin the game samples and the files the repo's import tools take. Mirrors tools/blender/motion_test.py
export() (skin.json/.skinw format) on the rig itself.
- <out>/croc_adult3.glb: the mesh at rest, turned to face -Y (rig_voxel / skin_faces / motion_test input).
- <out>/croc_adult3.skin.json + .skinw: the 37 r10 bones (helpers folded: half k -> (1-k) parent + k target,
  counter -> parent, forearm twist k -> (1-k) forearm + k hand), welded positions, top-4 weights, game axes.
- r11's eyelids are Blender-only (D-228): the lid bones fold into the head, and the lower-lid flaps (rigid shells
  hidden inside the head at rest, all their weight on lid_lo_*) are left out of every file, so the game mesh is r10's.
- <out>/croc_adult3_landmarks.json: motion_test landmarks at the r10 joints (so its clips' game bones rest on them).
The repo keeps the landmarks as assets/kaiju/test/croc_adult3_landmarks.json (motion_test.py <it> <glb> <out> clips).
blender -b croc_adult3_rig_r11.blend --python tools/blender/croc_adult3_export.py -- <out_dir> [height_vox=320]"""
import bpy, bmesh, sys, json, math
from pathlib import Path
import numpy as np
from mathutils import Matrix, Vector as V

a = sys.argv[sys.argv.index("--") + 1:]
OUT = Path(a[0]); OUT.mkdir(parents=True, exist_ok=True)
HV = int(a[1]) if len(a) > 1 else 320
STEM = "croc_adult3"
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]; ad = arm.data
mesh = bpy.data.objects["croc_mesh"]; me = mesh.data
R = Matrix.Rotation(-math.pi / 2, 4, "Z")  # r10 faces +X, left +Y -> faces -Y, left +X (motion_test's frame)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
ROLLS = {e.name: e.roll for e in ad.edit_bones}
bpy.ops.object.mode_set(mode="OBJECT")
GAME = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])

# --- drop the lower-lid flaps (r11; in memory only, the .blend is never saved) ----------------------------
FLAPS = {g.index for g in mesh.vertex_groups if g.name.startswith("lid_lo")}
bm = bmesh.new()
bm.from_mesh(me)
dl = bm.verts.layers.deform.verify()
flap = [v for v in bm.verts if any(i in FLAPS and w > 0.0 for i, w in v[dl].items())]
bmesh.ops.delete(bm, geom=flap, context="VERTS")
bm.to_mesh(me)
bm.free()
print("FLAPS dropped", len(flap), "vertices; mesh now", len(me.vertices))

# --- fold the helpers ---------------------------------------------------------------------------------
HELP = {}
for pb in arm.pose.bones:
    c = next((c for c in pb.constraints if c.name.startswith("r10_")), None)
    if c is None:
        continue
    par = pb.parent
    while par is not None and any(k.name.startswith("r10_") for k in par.constraints):
        par = par.parent
    kind, k = c.name[4:], c.influence
    if kind == "half":
        HELP[pb.name] = {par.name: 1 - k, c.subtarget: k}
    elif kind == "twist":
        HELP[pb.name] = {par.name: 1 - k, c.subtarget: k} if c.subtarget != par.name else {par.name: 1.0}
    else:
        HELP[pb.name] = {par.name: 1.0}
for pb in arm.pose.bones:
    if pb.name.startswith("lid_"):  # r11 eyelids (Blender-only): the head carries them
        HELP[pb.name] = {"head": 1.0}
print("FOLD", {h: {b: round(w, 3) for b, w in m.items()} for h, m in HELP.items()})
order = []
def visit(b):
    if b.name not in HELP and b.use_deform:
        order.append(b)
    for c in b.children:
        visit(c)
for b in ad.bones:
    if b.parent is None:
        visit(b)
NAMES = [b.name for b in order]
gnames = [g.name for g in mesh.vertex_groups]
W = np.zeros((len(me.vertices), len(NAMES)))
for v in me.vertices:
    for x in v.groups:
        n = gnames[x.group]
        for b, f in (HELP[n].items() if n in HELP else ((n, 1.0),)):
            if b in NAMES:
                W[v.index, NAMES.index(b)] += x.weight * f

# --- frames ---------------------------------------------------------------------------------------------
MW = R @ mesh.matrix_world
AW = R @ arm.matrix_world
P = np.array([tuple(MW @ v.co) for v in me.vertices])
LO, HI = P.min(0), P.max(0)
S = 100.0 / (HI[2] - LO[2])
norm = lambda p: (np.asarray(p, float) - np.array([(LO[0] + HI[0]) / 2, LO[1], LO[2]])) * S
head = {b.name: AW @ b.head_local for b in ad.bones}
tail = {b.name: AW @ b.tail_local for b in ad.bones}
ROOT = np.array([0.0, norm(head["pelvis"])[1], 0.0])
skin = lambda p: GAME @ (norm(p) - ROOT)

def game_bone(n):
    sd = "l" if n.endswith("_l") else "r"
    fixed = {"pelvis": "spine0", "lumbar0": "spine1", "lumbar1": "spine1", "chest": "spine2", "neck0": "head0",
             "neck1": "head0", "neck2": "head0", "head": "head1", "jaw": "jaw"}
    if n in fixed:
        return fixed[n]
    if n.startswith("tail"):
        return f"tail{min(int(n[4:]), 8)}"
    return {"clavicle": "spine2", "upperarm": f"arm_{sd}0", "forearm": f"arm_{sd}1", "hand": f"arm_{sd}2",
            "thigh": f"leg_{sd}0", "shin": f"leg_{sd}1", "foot": f"leg_{sd}2", "toe": f"leg_{sd}2"}[n[:-2]]

bones = []
for b in order:
    basis = np.array((AW.to_3x3() @ b.matrix_local.to_3x3()))
    bones.append({"name": b.name, "game": game_bone(b.name), "parent": b.parent.name if b.parent else None,
                  "head": skin(head[b.name]).round(4).tolist(), "tail": skin(tail[b.name]).round(4).tolist(),
                  "basis": (GAME @ basis).T.round(5).tolist(), "roll_blender": round(float(ROLLS[b.name]), 5),
                  "physics": b.name.startswith("tail"), "jaw": b.name == "jaw"})

# --- welded positions and weights -----------------------------------------------------------------------
key = np.round(P, 6)
_, first = np.unique(key, axis=0, return_index=True)
first = np.sort(first)
pos, Wd = P[first], W[first]
top_i = np.argsort(-Wd, axis=1)[:, :4]
top = np.take_along_axis(Wd, top_i, axis=1)
top /= np.maximum(1e-9, top.sum(1, keepdims=True))
idx = top_i.astype(np.uint8); idx[top <= 0] = 255; top[top <= 0] = 0
g = np.array([skin(p) for p in pos], np.float32)
rec = np.zeros(len(g), dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])
rec["p"], rec["b"], rec["w"] = g, idx, top.astype(np.float32)
with open(OUT / f"{STEM}.skinw", "wb") as f:
    f.write(b"KSKW" + np.array([1, len(g)], "<u4").tobytes() + np.array([len(NAMES)], "<u2").tobytes())
    f.write(rec.tobytes())
sc = (HV - 1) / (HI[2] - LO[2])
origin = np.array([(LO[0] + HI[0]) / 2, (LO[1] + HI[1]) / 2, LO[2]])
def cell_to_skin(gc):
    k = np.array([-(gc[0] + 1), gc[2], gc[1]], float)
    return skin((k + 0.5) / sc + origin)
o0 = cell_to_skin((0, 0, 0)); M = np.eye(4)
for i in range(3):
    e = [0, 0, 0]; e[i] = 1
    M[:3, i] = cell_to_skin(e) - o0
M[:3, 3] = o0
gall = np.array([skin(p) for p in P])
doc = {"version": 1, "units": "m", "axes": "game: Y up, -Z forward, x = -blender x; origin on the ground under the "
       "pelvis; model normalised to 100 m tall", "height_m": 100.0, "source": STEM + " (croc adult3 a3174b0f, rig r11)",
       "bones": bones, "vertex_count": int(len(g)), "weights_file": f"{STEM}.skinw",
       "bbox_game": [gall.min(0).round(3).tolist(), gall.max(0).round(3).tolist()], "kvox_height": HV,
       "kvox_cell_to_skin": M.round(6).tolist(),
       "kvox_note": "p_skin = M @ (gx, gy, gz, 1): centre of a rig_voxel cell of the SAME glb at kvox_height."}
(OUT / f"{STEM}.skin.json").write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")

# --- landmarks for motion_test (its normalised frame, before its pelvis re-origin) -----------------------
nl = lambda n, end="h": norm(head[n] if end == "h" else tail[n]).round(3).tolist()
lm = {"spine": [nl("pelvis"), nl("lumbar0"), nl("chest"), nl("neck0")],
      "neck": [nl("neck0"), nl("neck2"), nl("head")], "snout": nl("head", "t"),
      "jaw": [nl("jaw"), nl("jaw", "t")],
      "arm": [nl("clavicle_l"), nl("upperarm_l"), nl("forearm_l"), nl("hand_l"), nl("hand_l", "t")],
      "leg": [nl("thigh_l"), nl("shin_l"), nl("foot_l"), nl("toe_l"), nl("toe_l", "t")],
      "tail": [nl(f"tail{i:02d}") for i in range(11)],
      "hands": {"low": [1.0, -1.0, 1.0], "high": [3.0, 2.0, 7.0]},
      "lift": 0.05, "tail_lift": 3.0, "tail_drag": 1.3, "tail_roar_lift": 5.0, "tail_breathe": 0.15, "belly": 31.0}
(OUT / f"{STEM}_landmarks.json").write_text(json.dumps(lm, indent=1), encoding="utf-8")

# --- the glb (rest mesh, no armature) -------------------------------------------------------------------
dup = bpy.data.objects.new("croc_adult3", me.copy())
bpy.context.scene.collection.objects.link(dup)
dup.data.transform(MW)
dup.vertex_groups.clear()
for o in bpy.context.scene.objects:
    o.select_set(o is dup)
bpy.context.view_layer.objects.active = dup
bpy.ops.export_scene.gltf(filepath=str(OUT / f"{STEM}.glb"), export_format="GLB", use_selection=True,
                          export_skins=False, export_animations=False, export_yup=True)
print(f"EXPORT {STEM}: {len(NAMES)} bones, {len(g)} welded of {len(P)}, height {HI[2]-LO[2]:.4f} m, "
      f"length {HI[1]-LO[1]:.4f} m, max infl {int((top > 0).sum(1).max())}")
