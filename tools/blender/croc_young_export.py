"""Game export of a young croc rig (baby / adolescent; croc-young-casc S1-S5, D-307: the adult r12's 37 joints plus the
four eyelid bones, D-335 blinks) onto the young croc's existing game skin.

The young rig .blend was built on the game skin itself: its croc_mesh vertices are the welded positions of
assets/kaiju/test/croctitan_<stage>.skinw in order (game -> blend: bx = -gz, by = -gx, bz = gy, times s = 0.37548 m /
the skin's height, minus the bbox centre), plus the lower-lid flaps. So the positions, the faces (.skinf) and the
kvox cell map stay as they are; this writes the new bones and weights:
- <out>/croctitan_<stage>.skin.json: the rig's deform bones in hierarchy order, game frame (head, tail, basis), with
  their game bone (the adult croc_adult3_export.py names: lumbar0+1 -> spine1, neck0-2 -> head0,
  toe -> leg_x3, tail00-11 -> tail0-11, lids and clavicles keep their names); tail0-8 are the spring tail ("physics").
- <out>/croctitan_<stage>.skinw: the same positions, top-4 weights per vertex (normalised), bone indices into that list.
The lower-lid flaps (rigid shells hidden inside the head at rest) are left out, as for the adult; the skin.json's
"lid_flaps" block (LID_FLAPS) is how tools/kaiju_skin/lid_flaps.py builds them in voxels instead.
blender -b <young rig .blend> --python tools/blender/croc_young_export.py -- <stage> <repo> <out_dir>"""
import bpy, sys, json
from pathlib import Path
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
STAGE, REPO, OUT = a[0], Path(a[1]), Path(a[2]); OUT.mkdir(parents=True, exist_ok=True)
STEM = "croctitan_" + STAGE
SRC = REPO / "assets/kaiju/test" / STEM
H_BLEND = 0.3754800  # the young rig blends share the adult r11 blend's height (m)
SPRING_TAIL = 8
# The game's voxel lower lids per stage (croc_adult3_export.py LID_FLAPS; lead 2026-10-28: adolescent turn 80, baby 100):
# depth = the rig flap's (baby 0.010 m, adolescent 0.008 m) in skin units; the rig's flap meshes match (y7).
LID_FLAPS = {"baby": {"depth": 2.66, "open": 100, "half": 30, "over": 16, "lat": 40, "band": 1.8, "gap": 0.9},
             "adolescent": {"depth": 2.13, "open": 80, "half": 30, "over": 16, "lat": 40, "band": 1.8, "gap": 0.9}}
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]; ad = arm.data
mesh = bpy.data.objects["croc_mesh"]; me = mesh.data

# --- the existing game skin: welded positions (game frame) ----------------------------------------------------------
raw = (SRC.with_suffix(".skinw")).read_bytes()
assert raw[:4] == b"KSKW"
n0 = int(np.frombuffer(raw[8:12], "<u4")[0])
G = np.frombuffer(raw[14:], dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])["p"].astype(np.float64)
assert len(G) == n0
s = H_BLEND / (G[:, 1].max() - G[:, 1].min())
raw_b = np.stack([-G[:, 2], -G[:, 0], G[:, 1]], -1) * s
c = (raw_b.min(0) + raw_b.max(0)) / 2
to_game = lambda B: (lambda q: np.stack([-q[..., 1], q[..., 2], -q[..., 0]], -1))((np.asarray(B, float) + c) / s)
L = np.array([[0.0, -1.0, 0.0], [0.0, 0.0, 1.0], [-1.0, 0.0, 0.0]])  # blend -> game directions

# --- the rig's skin vertices (flaps out) must be the game skin's, in order ------------------------------------------
gi = {g.index: g.name for g in mesh.vertex_groups}
flap = np.array([any(gi[q.group].startswith("lid_lo") and q.weight > 0 for q in v.groups) for v in me.vertices])
keep = np.nonzero(~flap)[0]
MW = mesh.matrix_world
B = np.array([tuple(MW @ me.vertices[int(i)].co) for i in keep])
assert len(keep) == n0, (len(keep), n0)
gap = np.abs(to_game(B) - G).max()
assert gap < 1e-3, gap
print("SKIN", STEM, "verts", n0, "flaps dropped", int(flap.sum()), "worst position gap %.2e game units" % gap)

# --- bones (hierarchy order) and weights --------------------------------------------------------------------------
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
ROLLS = {e.name: e.roll for e in ad.edit_bones}
bpy.ops.object.mode_set(mode="OBJECT")
order = []
def visit(b):
    if b.use_deform:
        order.append(b)
    for ch in b.children:
        visit(ch)
for b in ad.bones:
    if b.parent is None:
        visit(b)
NAMES = [b.name for b in order]

def game_bone(n):
    sd = "l" if n.endswith("_l") else "r"
    fixed = {"pelvis": "spine0", "lumbar0": "spine1", "lumbar1": "spine1", "chest": "spine2", "neck0": "head0",
             "neck1": "head0", "neck2": "head0", "head": "head1", "jaw": "jaw"}
    if n in fixed:
        return fixed[n]
    if n.startswith("lid_"):
        return n
    if n.startswith("tail"):
        return f"tail{int(n[4:])}"
    return {"clavicle": f"clavicle_{sd}", "upperarm": f"arm_{sd}0", "forearm": f"arm_{sd}1", "hand": f"arm_{sd}2",
            "thigh": f"leg_{sd}0", "shin": f"leg_{sd}1", "foot": f"leg_{sd}2", "toe": f"leg_{sd}3"}[n[:-2]]

AW = arm.matrix_world
bones = []
for b in order:
    basis = np.array(AW.to_3x3() @ b.matrix_local.to_3x3())
    hd, tl = to_game(np.array(AW @ b.head_local)), to_game(np.array(AW @ b.tail_local))
    bones.append({"name": b.name, "game": game_bone(b.name), "parent": b.parent.name if b.parent else None,
                  "head": hd.round(4).tolist(), "tail": tl.round(4).tolist(), "basis": (L @ basis).T.round(5).tolist(),
                  "roll_blender": round(float(ROLLS[b.name]), 5),
                  "physics": b.name.startswith("tail") and int(b.name[4:]) <= SPRING_TAIL, "jaw": b.name == "jaw"})
W = np.zeros((len(me.vertices), len(NAMES)))
for v in me.vertices:
    for q in v.groups:
        n = gi[q.group]
        if n in NAMES:
            W[v.index, NAMES.index(n)] += q.weight
W = W[keep]
assert (W.sum(1) > 0).all(), "unweighted skin vertex"
# --- D-374 corrective helper joints (Behemoth, croc-young-casc 10-30), as croc_adult3_export.py: weighted after the bones
# (.skinw index len(NAMES) + k); rows keyed by rig vertex index (flaps in), so they map through keep
HP = Path(__file__).with_name(f"{STEM}_helpers.json")
HELPERS = json.loads(HP.read_text(encoding="utf-8")) if HP.exists() else {"helpers": [], "verts": {}}
COLS = NAMES + [h["name"] for h in HELPERS["helpers"]]
W = np.c_[W, np.zeros((len(W), len(HELPERS["helpers"])))]
new_of = {int(o): n for n, o in enumerate(keep)}
for o, row in HELPERS["verts"].items():
    n = new_of[int(o)]; W[n] = 0.0
    for b, w in row.items():
        W[n, COLS.index(b)] = w
print("HELPERS", len(HELPERS["helpers"]), "rows", len(HELPERS["verts"]))
top_i = np.argsort(-W, axis=1)[:, :4]
top = np.take_along_axis(W, top_i, axis=1)
top /= np.maximum(1e-9, top.sum(1, keepdims=True))
idx = top_i.astype(np.uint8); idx[top <= 0] = 255; top[top <= 0] = 0
rec = np.zeros(n0, dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])
rec["p"], rec["b"], rec["w"] = G.astype(np.float32), idx, top.astype(np.float32)
with open(OUT / f"{STEM}.skinw", "wb") as f:
    f.write(b"KSKW" + np.array([1, n0], "<u4").tobytes() + np.array([len(COLS)], "<u2").tobytes())
    f.write(rec.tobytes())
doc = json.loads(SRC.with_suffix(".skin.json").read_text(encoding="utf-8"))
doc.update({"source": f"{STEM} (croc-young-casc rig: the adult r12 joints + eyelids)", "bones": bones,
            "vertex_count": int(n0), "weights_file": f"{STEM}.skinw", "lid_flaps": LID_FLAPS[STAGE]})
if HELPERS["helpers"]:
    doc["helpers"] = HELPERS["helpers"]
(OUT / f"{STEM}.skin.json").write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")
print(f"EXPORT {STEM}: {len(NAMES)} bones -> {len(set(b['game'] for b in bones))} game bones, max infl "
      f"{int((top > 0).sum(1).max())}, weight change from the rig {np.abs(top.sum(1) - 1).max():.1e}")
