"""Game export of the croc on the T-rex body (croc head, Randaling T-rex rig croc_rig; D-461): the skin the game samples
and the files the repo's import tools take, in the same format as tools/blender/croc_adult3_export.py.
- <out>/croc_trex.glb: the mesh at rest, facing -Y (rig_voxel / skin_faces input).
- <out>/croc_trex.skin.json + .skinw: the 40 game bones of the adult croc (spine0-2, head0, neck1, neck2, head1, jaw,
  clavicle_x, arm_x0-2, leg_x0-3, tail0-11, lid_up/lo_x), so the adult's keyed clips play on this rig too. Rig bones
  that are not game bones fold their skin into one (FOLD). HipHelp_x (COPY_ROTATION 0.5 of the thigh) becomes the
  helper joint hlp_hip_x (scenes/voxel_skin_helpers.gd), posed half way from spine0 to leg_x0, its skin its own column.
- <out>/croc_trex_landmarks.json: motion_test landmarks at the rig's joints.
blender -b croc_run21_ok.blend --python tools/blender/croc_trex_export.py -- <out_dir> [height_vox=320]"""
import bpy, sys, json
from pathlib import Path
import numpy as np
from mathutils import Matrix

a = sys.argv[sys.argv.index("--") + 1:]
OUT = Path(a[0]); OUT.mkdir(parents=True, exist_ok=True)
HV = int(a[1]) if len(a) > 1 else 320
STEM = "croc_trex"
arm = bpy.data.objects["croc_rig"]; ad = arm.data
mesh = bpy.data.objects["croc_final"]; me = mesh.data
R = Matrix.Identity(4)  # the rig already faces -Y with its left on +X (motion_test's frame)
GAME = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])
LID_FLAPS = {"depth": 2.13, "open": 100, "half": 30, "over": 16, "lat": 50, "band": 1.8, "gap": 0.9}  # adult3's
SPRING_TAIL = 8  # game tail0-8 bend on turns; tail9-11 follow clips only (as adult3)
HIP_FRAC = 0.5   # HipHelp_x's COPY_ROTATION influence


def game_bone(n):
    """Game bone of a rig bone that is one, else None."""
    if n.startswith("lid_"):
        return n
    sd = n[-1].lower()
    fixed = {"Hips_C": "spine0", "Spine1_C": "spine1", "Spine2_C": "spine2", "Neck1_C": "head0", "Neck2_C": "neck1",
             "Neck3_C": "neck2", "Head_C": "head1", "Jaw_C": "jaw"}
    if n in fixed:
        return fixed[n]
    if n.startswith("Tail"):  # Tail1_C, Tail1b_C .. Tail6b_C -> tail0..tail11
        k = int(n[4]); return f"tail{2 * k - 2 + (1 if n[5] == 'b' else 0)}"
    part = {"Clavicle": f"clavicle_{sd}", "Shoulder": f"arm_{sd}0", "Elbow": f"arm_{sd}1", "Wrist": f"arm_{sd}2",
            "Thigh": f"leg_{sd}0", "Knee": f"leg_{sd}1", "Ankle": f"leg_{sd}2", "Foot": f"leg_{sd}3"}
    return part.get(n[:-2])


def fold(n):
    """The game bone a non-game rig bone's skin goes into (none of these move against it in the clips)."""
    sd = n[-1]
    if n.startswith(("Tongue",)):
        return "Jaw_C"
    if n.startswith("Eye_"):
        return "Head_C"
    if n == "NeckMuscle_C":
        return "Neck2_C"
    if n.startswith("Hip_"):
        return "Hips_C"
    if n.startswith("ThighMuscle_"):
        return f"Thigh_{sd}"
    if n.startswith(("Finger", "HandClaw")):
        return f"Wrist_{sd}"
    if n.startswith(("Toe", "Claw")):
        return f"Foot_{sd}"
    return None  # _rootJoint, Hips, Cog_C: no skin


bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
ROLLS = {e.name: e.roll for e in ad.edit_bones}
bpy.ops.object.mode_set(mode="OBJECT")
def parent_of(b):
    """Nearest game-bone ancestor; Spine1_C hangs from Cog_C beside the pelvis in the rig, from spine0 in the game."""
    p = b.parent
    while p is not None and not game_bone(p.name):
        p = p.parent
    if p is None and b.name != "Hips_C":
        p = ad.bones["Hips_C"]
    return p.name if p is not None else None


kids = {}
for b in ad.bones:
    if game_bone(b.name):
        kids.setdefault(parent_of(b), []).append(b)
order = []
def visit(n):  # parents first, along the game's parents
    for b in kids.get(n, []):
        order.append(b); visit(b.name)
visit(None)
NAMES = [b.name for b in order]
assert len(NAMES) == 40, NAMES
HELPERS = [{"name": f"hlp_hip_{s}", "a": "spine0", "b": f"leg_{s}0", "frac": HIP_FRAC, "grow": False,
            "centre": None, "push": [0.0, 0.0, 0.0], "per_turn": [[0.0, 0.0, 0.0]] * 3} for s in ("l", "r")]
HNAMES = [h["name"] for h in HELPERS]
HELP_OF = {f"HipHelp_{s.upper()}": f"hlp_hip_{s}" for s in ("l", "r")}
COLS = NAMES + HNAMES
gnames = [g.name for g in mesh.vertex_groups]
W = np.zeros((len(me.vertices), len(COLS)))
lost = {}
for v in me.vertices:
    for x in v.groups:
        n = gnames[x.group]
        col = HELP_OF.get(n) or (n if n in NAMES else fold(n))
        if col is None:
            lost[n] = lost.get(n, 0) + x.weight; continue
        W[v.index, COLS.index(col)] += x.weight
assert not any(w > 0 for w in lost.values()), f"skin on bones with no game bone: {lost}"
assert (W.sum(1) > 0).all(), f"{int((W.sum(1) <= 0).sum())} vertices with no weight"


# --- frames ---------------------------------------------------------------------------------------------
MW = R @ mesh.matrix_world
AW = R @ arm.matrix_world
P = np.array([tuple(MW @ v.co) for v in me.vertices])
LO, HI = P.min(0), P.max(0)
S = 100.0 / (HI[2] - LO[2])
norm = lambda p: (np.asarray(p, float) - np.array([(LO[0] + HI[0]) / 2, LO[1], LO[2]])) * S
head = {b.name: AW @ b.head_local for b in ad.bones}
tail = {b.name: AW @ b.tail_local for b in ad.bones}
for _s in "LR":  # the foot bone stands upright; the game toe tip (leg_x3 tail) is the middle toe's tip
    tail[f"Foot_{_s}"] = tail[f"ToeMiddle_{_s}"]
ROOT = np.array([0.0, norm(head["Hips_C"])[1], 0.0])
skin = lambda p: GAME @ (norm(p) - ROOT)
for h, s in zip(HELPERS, ("L", "R")):  # the helper turns about the hip joint (the thigh's head)
    h["centre"] = skin(head[f"Thigh_{s}"]).round(4).tolist()

bones = []
for b in order:
    basis = np.array((AW.to_3x3() @ b.matrix_local.to_3x3()))
    g = game_bone(b.name)
    bones.append({"name": b.name, "game": g, "parent": parent_of(b),
                  "head": skin(head[b.name]).round(4).tolist(), "tail": skin(tail[b.name]).round(4).tolist(),
                  "basis": (GAME @ basis).T.round(5).tolist(), "roll_blender": round(float(ROLLS[b.name]), 5),
                  "physics": g.startswith("tail") and int(g[4:]) <= SPRING_TAIL, "jaw": g == "jaw"})

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
    f.write(b"KSKW" + np.array([1, len(g)], "<u4").tobytes() + np.array([len(COLS)], "<u2").tobytes())
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
       "pelvis; model normalised to 100 m tall", "height_m": 100.0, "source": STEM + " (croc head on the Randaling T-rex "
       "rig, croc_run21_ok)", "bones": bones, "helpers": HELPERS, "vertex_count": int(len(g)),
       "weights_file": f"{STEM}.skinw", "bbox_game": [gall.min(0).round(3).tolist(), gall.max(0).round(3).tolist()],
       "kvox_height": HV, "kvox_cell_to_skin": M.round(6).tolist(), "lid_flaps": LID_FLAPS,
       "kvox_note": "p_skin = M @ (gx, gy, gz, 1): centre of a rig_voxel cell of the SAME glb at kvox_height."}
(OUT / f"{STEM}.skin.json").write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")

# --- landmarks for motion_test (its normalised frame, before its pelvis re-origin) -----------------------
nl = lambda n, end="h": norm(head[n] if end == "h" else tail[n]).round(3).tolist()
tails = [b.name for b in order if b.name.startswith("Tail")]
lm = {"spine": [nl("Hips_C"), nl("Spine1_C"), nl("Spine2_C"), nl("Neck1_C")],
      "neck": [nl("Neck1_C"), nl("Neck3_C"), nl("Head_C")], "snout": nl("Head_C", "t"),
      "jaw": [nl("Jaw_C"), nl("Jaw_C", "t")],
      "arm": [nl("Clavicle_L"), nl("Shoulder_L"), nl("Elbow_L"), nl("Wrist_L"), nl("Wrist_L", "t")],
      "leg": [nl("Thigh_L"), nl("Knee_L"), nl("Ankle_L"), nl("Foot_L"), nl("ToeMiddle_L", "t")],
      "tail": [nl(t) for t in tails[:11]],
      "hands": {"low": [1.0, -1.0, 1.0], "high": [3.0, 2.0, 7.0]},
      "lift": 0.05, "tail_lift": 3.0, "tail_drag": 1.3, "tail_roar_lift": 5.0, "tail_breathe": 0.15, "belly": 31.0}
(OUT / f"{STEM}_landmarks.json").write_text(json.dumps(lm, indent=1), encoding="utf-8")

# --- the glb (rest mesh, no armature) -------------------------------------------------------------------
dup = bpy.data.objects.new(STEM, me.copy())
bpy.context.scene.collection.objects.link(dup)
dup.data.transform(MW)
dup.vertex_groups.clear()
for o in bpy.context.scene.objects:
    o.select_set(o is dup)
bpy.context.view_layer.objects.active = dup
bpy.ops.export_scene.gltf(filepath=str(OUT / f"{STEM}.glb"), export_format="GLB", use_selection=True,
                          export_skins=False, export_animations=False, export_yup=True)
print(f"EXPORT {STEM}: {len(NAMES)} bones {sorted(game_bone(n) for n in NAMES)}, {len(HELPERS)} helpers, "
      f"{len(g)} welded of {len(P)}, height {HI[2]-LO[2]:.4f}, length {HI[1]-LO[1]:.4f}, "
      f"max infl {int((top > 0).sum(1).max())}")
