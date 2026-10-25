"""Adds the r10d standing stomp (Cascadeur keys, D-199) to the adult croc's .kclip as the looping clip "stomp": one
42-frame cycle at 30 fps (left lifts at 0, right at 21; two stomps 0.7 s apart) sampled to N frames (42: the keyed
frames, which StompBeat plays at their own pace), as game-bone local turns, pelvis offset, toe tips and planted bits (tools/blender/motion_test.py
clips_export() format, the export_game_r10.py frame: turned to face -Y, 100 m tall, origin under the pelvis).
blender -b cascadeur_bridge/croc_new/stomp_r10/stomp_r10d.blend --python tools/blender/croc_adult3_stomp.py --
    <in.kclip> <out.kclip> [cycle_start=86] [frames=42]   (the r10d keys: stomp_r10/stomp_r10_keys.py)"""
import bpy, sys, json, math, struct
import numpy as np
from mathutils import Matrix, Quaternion, Vector as V

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
C0 = int(a[2]) if len(a) > 2 else 86
N = int(a[3]) if len(a) > 3 else 42
CYCLE = 42
arm = bpy.data.objects["croc_rig"]; ad = arm.data
mesh = bpy.data.objects["croc_mesh"]; me = mesh.data
scene = bpy.context.scene
R = Matrix.Rotation(-math.pi / 2, 4, "Z")
G3 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
M3 = G3 @ R.to_3x3()
HELPER = lambda n: "_hlp" in n or "_tw" in n


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


raw = open(SRC, "rb").read()
hl = struct.unpack_from("<I", raw, 8)[0]
header = json.loads(raw[12:12 + hl]); body = raw[12 + hl:]
GB = header["bones"]
FB = header["frame_bytes"]
assert all(c["name"] != "stomp" for c in header["clips"]), "already has a stomp"
# Rest frame: the mesh at rest (as export_game_r10.py): bbox -> 100 m tall, origin on the ground under the pelvis.
AW = R @ arm.matrix_world
P = np.array([tuple(R @ mesh.matrix_world @ v.co) for v in me.vertices])
LO, HI = P.min(0), P.max(0)
S = 100.0 / (HI[2] - LO[2])
C = np.array([(LO[0] + HI[0]) / 2, LO[1], LO[2]])
ROOT_Y = ((AW @ ad.bones["pelvis"].head_local)[1] - C[1]) * S
def skin(p):
    q = (np.array(tuple(p)) - C) * S - np.array([0.0, ROOT_Y, 0.0])
    return V(tuple(np.array(G3) @ q))

deform = [b for b in ad.bones if b.use_deform and not HELPER(b.name)]
first, last = {}, {}
for b in deform:  # parents first (bone order); a bone starting on the chain's end extends it
    g = game_bone(b.name)
    first.setdefault(g, b)
    if g not in last or (b.parent is not None and b.parent.name == last[g].name
                         and (b.head_local - last[g].tail_local).length < 1e-4):
        last[g] = b
assert set(first) == set(GB), set(GB) ^ set(first)
heads = {g: skin(AW @ first[g].head_local) for g in GB}
worst_rest = max((V(header["rest_heads_m"][g]) - heads[g]).length for g in GB)
print("rest heads vs the file: worst %.3f m" % worst_rest)
REST_TOE = skin(AW @ ad.bones["toe_l"].tail_local).y


def game_pose():
    world, quats = {}, []
    for g in GB:
        f, l = arm.pose.bones[first[g].name], arm.pose.bones[last[g].name]
        turn = f.matrix.to_quaternion() @ first[g].matrix_local.to_quaternion().inverted()
        rest_dir = last[g].tail_local - first[g].head_local
        swing = (turn @ rest_dir).rotation_difference(l.tail - f.head)
        w = (M3 @ (swing @ turn).to_matrix() @ M3.transposed()).to_quaternion()
        world[g] = w
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        quats.append(((world[pg].inverted() @ w) if pg else w).normalized())
    off = skin(AW @ arm.pose.bones["pelvis"].head) - heads["spine0"]
    feet = [skin(AW @ arm.pose.bones[f"toe_{s}"].tail) for s in ("l", "r")]
    return quats, off, feet


def pose_at(t):  # source frame t (fractional) -> pose via the two nearest frames (slerp, lerp)
    f0 = math.floor(t); k = t - f0
    scene.frame_set(f0); q0, o0, ft0 = game_pose()
    if k < 1e-6:
        return q0, o0, ft0
    scene.frame_set(f0 + 1); q1, o1, ft1 = game_pose()
    return ([x.slerp(y, k) for x, y in zip(q0, q1)], o0.lerp(o1, k), [x.lerp(y, k) for x, y in zip(ft0, ft1)])


cm = lambda v: [int(round(c * 100.0)) for c in v]
out, lows = bytearray(), []
for i in range(N):
    qs, off, feet = pose_at(C0 + i * CYCLE / N)
    planted = [ft.y < REST_TOE + 0.25 for ft in feet]  # toe tip within 25 cm of its rest height (100 m model)
    lows.append((round(feet[0].y, 2), round(feet[1].y, 2)))
    for q in qs:
        out += struct.pack("<4h", *(int(round(c * 32767.0)) for c in (q.x, q.y, q.z, q.w)))
    out += struct.pack("<3h", *cm(off)) + struct.pack("<6h", *(cm(feet[0]) + cm(feet[1])))
    out += struct.pack("<h", 0) + struct.pack("<2h", 0, 0)
    out += struct.pack("<BB", (1 if planted[0] else 0) | (2 if planted[1] else 0), 0)
assert len(out) == N * FB
start = sum(c["frames"] for c in header["clips"])
# Footfalls (clip frames): the 30 fps contacts at cycle frames 12 (left) and 33 (right).
header["clips"].append({"name": "stomp", "first": start, "frames": N, "loop": True, "cycles": 1,
                        "stomps": [{"side": "left", "lift": 0.0, "land": round(12 * N / CYCLE, 3)},
                                   {"side": "right", "lift": round(21 * N / CYCLE, 3), "land": round(33 * N / CYCLE, 3)}],
                        "source": "Cascadeur r10d (croc_adult3_stomp_r10d.casc), 30 fps cycle of 42 frames"})
hb = json.dumps(header, separators=(",", ":")).encode()
open(DST, "wb").write(b"KCLP" + struct.pack("<II", 1, len(hb)) + hb + body + bytes(out))
print("STOMP %d frames from %d..%d; toe heights (m) per frame:" % (N, C0, C0 + CYCLE), lows)
