"""Motion test and rig export: one hand-built armature, fitted to a kaiju mesh at its real pivots,
scripted weights with clean joint falloff, keyed clips (idle, walk, 90 degree turn, roar), and
exports of the rig, its welded weights (the game's voxel skin) and the clips (the game plays them).

    blender -b --python tools/blender/motion_test.py -- <A|B|C|auto|landmarks.json> <in.glb> <out> <task> [clips]

Fit: A, B and C (the D-046 croc titan) use pivots measured by hand on those meshes; auto finds them by slicing the mesh (a
biped kaiju facing -Y: legs, tail, arms out); a .json gives them explicitly (same keys as LANDMARKS,
metres in the normalised frame). task: render (PNG frames per clip and view), measure (foot slide
JSON), volume (girth kept per joint), crops (joint close-ups), blend (save the rigged, keyed .blend),
export (<out>/<stem>.skin.json + .skinw for the game, see export()), fit (landmark report), diff
(per-frame pose change and seams), tail (the tail's sweep, bends and
clearance per clip), tailtop (top-down still with the tail's paths), clips (<out>/<stem>.kclip for the game's ClipGait, see
clips_export(); D-047). clips: comma list of idle,walk,turn,roar (default walk,turn,roar). Run one clip per Blender process: re-keying a
second clip in the same process left the first frame posed from the old action.
Units: metres, every model normalised to 100 m tall, facing -Y, feet on z = 0, origin on the ground
under the pelvis.
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector as V

ARGS = sys.argv[sys.argv.index("--") + 1:]
MODEL, SRC, OUT, TASK = ARGS[0], ARGS[1], Path(ARGS[2]), ARGS[3]
CLIPS = ARGS[4].split(",") if len(ARGS) > 4 else ["walk", "turn", "roar"]
OUT.mkdir(parents=True, exist_ok=True)
FPS, FRAMES = 24, 336  # 336 frames: seven walk cycles with four whole tail waves; other clips use fewer
RES = (640, 480)
# Optional overrides for board renders: MT_VIEWS=high MT_RES=960x920 (default: side + three-quarter, 640x480).
import os
if os.environ.get("MT_RES"):
    RES = tuple(int(x) for x in os.environ["MT_RES"].split("x"))


# --- landmarks (the real pivots, measured on each mesh; left side, right is mirrored) -------------

def a_pt(x, y, z):
    """A was built in its own frame (build_reptile.py); normalised = (y + 51.517) * 0.99397."""
    k = 0.99397
    return V((x * k, (y + 51.517) * k, z * k))


KNOWN = {
    "A": dict(
        spine=[a_pt(0, 12, 45), a_pt(0, 4, 56), a_pt(0, -3, 66), a_pt(0, -7, 74)],
        neck=[a_pt(0, -7, 74), a_pt(0, -12, 83), a_pt(0, -18, 89)],
        snout=a_pt(0, -50, 88), jaw=(a_pt(0, -20, 86), a_pt(0, -48, 81.5)),
        arm=[a_pt(3, -5, 72), a_pt(11, -8, 71), a_pt(26, -12, 68.3), a_pt(34, -18, 67), a_pt(43, -23, 64.5)],
        leg=[a_pt(10.5, 10, 46), a_pt(15, -2, 27), a_pt(14.5, 17, 9), a_pt(14.5, 3, 2.5), a_pt(14.5, -7, 1.8)],
        tail=[a_pt(0, 16, 44), a_pt(0, 30, 38), a_pt(0, 46, 30), a_pt(0, 62, 22), a_pt(0, 78, 15),
              a_pt(0, 94, 10.5), a_pt(0, 108, 8), a_pt(0, 120, 7)],
        belly=21.0),
    "B": dict(
        spine=[V((0, 34, 46)), V((0, 30, 58)), V((0, 28, 69)), V((0, 28, 78))],
        neck=[V((0, 28, 78)), V((0, 25, 85)), V((0, 22, 91))],
        snout=V((0, 1, 91)), jaw=(V((0, 20, 87)), V((0, 5, 83))),
        arm=[V((4, 30, 74)), V((15, 30, 76)), V((30, 25, 71)), V((39, 9, 73)), V((49, 4, 71))],
        leg=[V((12, 32, 45)), V((17.5, 23, 25)), V((17.5, 31, 10)), V((21, 19, 2.5)), V((22, 12, 1))],
        tail=[V((0, 40, 38)), V((2.6, 48, 27)), V((1.8, 59, 24)), V((3, 68, 19.5)), V((6.5, 77, 15)),
              V((11, 85, 12.3)), V((17, 93, 11.7)), V((22, 101, 11)), V((29, 108, 16)), V((38, 117, 19))],
        belly=13.0),
    # C: the D-046 "Croc titan", v2 (Tripo Smart Mesh c8185166, lead 22:47): an upright croc-theropod
    # with short T-rex arms and a 185 m tail that tapers to the ground, measured on 1 m grid side and
    # front renders and vertex slices (v1, task 351ad916, is in this file's history).
    "C": dict(
        spine=[V((0, 80, 55)), V((0, 68, 61)), V((0, 56, 67)), V((0, 47, 73))],
        neck=[V((0, 47, 73)), V((0, 40, 80)), V((0, 33, 86))],
        snout=V((0, 0.5, 84)), jaw=(V((0, 30, 85.5)), V((0, 2, 82))),
        # The closed mouth's tooth line, tip to gape corner (read off a side render of the head).
        mouth=(V((0, 1, 84)), V((0, 27.5, 87.3))),
        arm=[V((5, 46, 73)), V((16, 44, 71)), V((24, 38, 66)), V((27, 35, 62)), V((28, 33, 55))],
        leg=[V((14, 72, 50)), V((22, 62, 35)), V((26, 72, 17)), V((29, 62, 3)), V((30, 50, 1))],
        tail=[V((0, 86, 52)), V((0, 104.5, 47)), V((0, 123, 38)), V((0, 141.5, 30)), V((0, 160, 26)),
              V((0, 178.5, 22)), V((0, 197, 19)), V((0, 215.5, 16)), V((0, 234, 12)), V((0, 252.5, 8.5)),
              V((0, 271, 3))],
        # Short arms: the hand targets are offsets from each rest wrist (in, back, up; metres):
        # tucked low on the walk, claws up to the chest at the roar.
        hands={"low": (1.0, -1.0, 1.0), "high": (3.0, 2.0, 7.0)},
        # The 185 m tail rests on its tip: carry it a little off the street, lift it harder against
        # the roar's pelvis tip, breathe it less (degrees).
        tail_lift=3.0, tail_roar_lift=5.0, tail_breathe=0.15,
        belly=31.0),
    # The croc titan baby (stage 1, Tripo edf7bb50): a cub's big head and squat legs, arms in a T-pose
    # (straight out at shoulder height), a long tail lying on the street. Measured on 1 m grid side,
    # front and head renders. Quick and bouncy: a shorter stride in a 36-frame cycle (four per clip).
    "CB": dict(
        spine=[V((0, 88, 38)), V((0, 76, 48)), V((0, 64, 58)), V((0, 54, 66))],
        neck=[V((0, 54, 66)), V((0, 47, 74)), V((0, 42, 80))],
        snout=V((0, 0.5, 82.5)), jaw=(V((0, 39, 85)), V((0, 2, 79.5))),
        mouth=(V((0, 1, 81)), V((0, 36, 86.5))),
        arm=[V((6, 56, 64)), V((17, 56, 62)), V((38, 56, 61)), V((56, 56, 60)), V((67, 56, 59))],
        leg=[V((18, 80, 33)), V((24, 68, 20)), V((28, 82, 7)), V((30, 68, 2)), V((30, 58, 1))],
        tail=[V((0, 96, 36)), V((0, 104, 30)), V((0, 112, 25)), V((0, 120, 19)), V((0, 132, 14)),
              V((0, 144, 11)), V((0, 156, 9.5)), V((0, 168, 8.5)), V((0, 180, 8)), V((0, 192, 6.5)),
              V((0, 211, 3.5))],
        # T-pose arms: the hands come down in front of the belly (in, back, up from the rest wrist).
        hands={"low": (42.0, -8.0, -12.0), "high": (44.0, -6.0, 2.0)},
        tail_lift=4.0, tail_roar_lift=5.0, tail_breathe=0.2,
        # The game moves the cub as fast as the adult on legs a third the size: the longest stride its
        # legs reach (44 m) and a slow tail (a wave every 3.5 strides) keep it quick, not frantic.
        belly=12.0, stride=44.0, cycle=36.0, bounce=1.8, tail_strides=3.5, tail_sway=0.4,
        # Seen from the game camera its feet hid under the belly (lead review, PR #54): a toddler's
        # sprawl, feet 10 m wider, and a high stomping lift.
        splay=10.0, lift=0.18),
    # The adolescent (stage 2, Tripo 109910f0, imported turned 90 deg to face -Y): lanky, long legs,
    # arms hanging forward, the tail held level at hip height. A long, gangly stride.
    "CA": dict(
        spine=[V((0, 80, 60)), V((0, 66, 64)), V((0, 52, 70)), V((0, 42, 76))],
        neck=[V((0, 42, 76)), V((0, 35, 82)), V((0, 28, 87))],
        snout=V((0, 0.3, 88)), jaw=(V((0, 21, 88)), V((0, 2, 85.5))),
        mouth=(V((0, 1, 86.8)), V((0, 19, 89.6))),
        arm=[V((6, 44, 74)), V((17, 40, 72)), V((20, 32, 63)), V((22, 24, 56)), V((22, 20, 50))],
        leg=[V((12, 72, 55)), V((13, 78, 24)), V((14, 73, 8)), V((16, 62, 2)), V((18, 52, 0.5))],
        tail=[V((0, 86, 59)), V((0, 98, 58)), V((0, 110, 57.5)), V((0, 122, 58)), V((0, 134, 58.5)),
              V((0, 146, 60)), V((0, 158, 61.5)), V((0, 170, 63)), V((0, 182, 64)), V((0, 195, 64.8)),
              V((0, 208, 64.8))],
        hands={"low": (1.0, -1.0, 1.0), "high": (3.0, 3.0, 8.0)},
        tail_lift=0.0, tail_roar_lift=2.5, tail_breathe=0.3,
        belly=15.0, stride=56.0, cycle=48.0, bounce=1.2,
        # Its feet track under the body: set them out past the belly and lift them clear (PR #54).
        splay=12.0, lift=0.15),
}
TAIL_BONES = 10


def resample(points, n):
    """n + 1 points evenly spaced along a polyline."""
    pts = [V(p) for p in points]
    seg = [(b - a).length for a, b in zip(pts, pts[1:])]
    total = sum(seg)
    out = []
    for k in range(n + 1):
        d = total * k / n
        for i, s in enumerate(seg):
            if d <= s or i == len(seg) - 1:
                out.append(pts[i].lerp(pts[i + 1], min(1.0, d / s)))
                break
            d -= s
    return out


# --- load and normalise -----------------------------------------------------------------------------

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in scene.objects if o.type == "MESH"]
world = {o.name: o.matrix_world.copy() for o in meshes}
pts = np.concatenate([np.array([world[o.name] @ v.co for v in o.data.vertices]) for o in meshes])
SRC_LO, SRC_HI = pts.min(0), pts.max(0)
lo, hi = SRC_LO, SRC_HI
s = 100.0 / (hi[2] - lo[2])
norm0 = Matrix.Scale(s, 4) @ Matrix.Translation((-(lo[0] + hi[0]) / 2, -lo[1], -lo[2]))
for o in meshes:
    o.parent = None
    o.data.transform(norm0 @ world[o.name])
    o.matrix_world = Matrix.Identity(4)
for o in [o for o in scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)


def all_vertices():
    return np.concatenate([np.array([v.co for v in o.data.vertices]) for o in meshes])


def auto_landmarks(v):
    """Pivots of a biped kaiju found by slicing the normalised mesh (100 m tall, facing -Y). Joint
    rules: hip at 46% height, knee = the most forward leg slice, ankle = the most backward one below
    it, ball = the front half of the foot; spine and neck from the core (|x| < 6 m); arms traced
    outward; tail from bands behind the hips. Checked against the hand-measured A and B (task fit)."""
    def cen(m, n=8):
        return V(v[m].mean(0)) if m.sum() >= n else None
    core = np.abs(v[:, 0]) < 6
    feet = (v[:, 2] < 2.5) & (np.abs(v[:, 0]) > 5)
    foot_y = float(np.median(v[feet, 1]))
    up = (v[:, 2] > 80) & (np.abs(v[:, 0]) < 8)
    tip = v[up][np.argmin(v[up][:, 1])]
    snout = V((0, tip[1], tip[2]))
    head_len = None

    def mid(zz, ymax):
        """Middle of the torso at height zz: halfway between its front and back (2nd/98th pct: vertex
        density is uneven, belly folds are dense, so a centroid or median sits too far forward)."""
        ys = v[core & (np.abs(v[:, 2] - zz) < 1.5) & (v[:, 1] < ymax) & (v[:, 1] > snout.y + 8), 1]
        return float(np.percentile(ys, 2) + np.percentile(ys, 98)) / 2

    pel = V((0, mid(46, foot_y + 40), 46))  # the slice's back is the rump; beyond it, only tail
    spine = [pel] + [V((0, mid(zz, pel.y + 14), zz)) for zz in (58, 69, 78)]
    neck0 = spine[-1]
    # Skull base: ~76% of the way from the snout back to the neck base (A 0.74, B 0.78 by hand).
    head0 = V((0, snout.y + 0.76 * (neck0.y - snout.y), max(snout.z + 1.0, neck0.z + 8.0)))
    neck = [neck0, (neck0 + head0) / 2, head0]
    hinge = V((0, head0.y - 0.1 * (head0.y - snout.y), head0.z - 4))
    jaw = (hinge, snout + V((0, 3, -7)))
    left = v[:, 0] > 0
    leg_zone = lambda zz: left & (v[:, 0] > 4) & (np.abs(v[:, 2] - zz) < 1.2) &         (v[:, 1] < pel.y + (12 if zz > 20 else 18)) & (v[:, 1] > foot_y - 30)
    hip = cen(leg_zone(45))
    hip = V((hip.x * 0.85, hip.y, 45))
    slices = [(zz, cen(leg_zone(zz))) for zz in np.arange(14, 41, 1.0)]
    slices = [(zz, c) for zz, c in slices if c is not None]
    kz, knee = min(slices, key=lambda t: t[1].y)
    low = [(zz, cen(leg_zone(zz))) for zz in np.arange(5, kz - 3, 1.0)]
    low = [(zz, c) for zz, c in low if c is not None]
    az, ankle = max(low, key=lambda t: t[1].y)
    foot = v[left & feet]
    front = foot[foot[:, 1] < np.median(foot[:, 1])]
    ball = V((front[:, 0].mean(), front[:, 1].mean(), 2.5))
    toe_p = foot[np.argmin(foot[:, 1])]
    toe = V((toe_p[0], toe_p[1], 1.0))
    arms = v[left & (v[:, 2] > 55) & (v[:, 1] < pel.y + 10)]
    mx = arms[:, 0].max()
    def arm_at(f):
        b_ = arms[np.abs(arms[:, 0] - f * mx) < 1.5]
        return V((f * mx, b_[:, 1].mean(), b_[:, 2].mean()))
    sh = arm_at(0.32)
    arm = [V((0.08 * mx, sh.y, sh.z)), sh, arm_at(0.6), arm_at(0.8), arm_at(0.97)]
    tail = [V((0, pel.y + 6, pel.z - 6))]
    yt = v[:, 1].max()
    for yy in np.arange(pel.y + 12, yt - 2, 7.0):
        c = cen((np.abs(v[:, 1] - yy) < 2) & (v[:, 2] < pel.z), 5)
        if c is not None:
            tail.append(V((c.x, yy, c.z)))
    end = v[v[:, 1] > yt - 2].mean(0)
    tail.append(V((end[0], yt, end[2])))
    s1 = spine[1]
    front_y = v[core & (np.abs(v[:, 2] - s1.z) < 2), 1].min()
    return dict(spine=spine, neck=neck, snout=snout, jaw=jaw, arm=arm,
                leg=[hip, knee, ankle, ball, toe], tail=tail, belly=float(s1.y - front_y + 3.0))


def load_landmarks(path):
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    conv = lambda x: V(x) if isinstance(x[0], (int, float)) else [V(p) for p in x]
    return {k: (conv(val) if isinstance(val, list) else val) for k, val in d.items()}


if MODEL in KNOWN:
    LANDMARKS = {k: (V(x) if isinstance(x, V) else type(x)(V(p) for p in x) if isinstance(x, (list, tuple)) else x)
                 for k, x in KNOWN[MODEL].items()}
elif MODEL == "auto":
    LANDMARKS = auto_landmarks(all_vertices())
else:
    LANDMARKS = load_landmarks(MODEL)
# Re-origin on the pelvis' ground point: the rig turns about the hips, not the snout.
ROOT_Y = LANDMARKS["spine"][0].y
for key, val in list(LANDMARKS.items()):
    if isinstance(val, V):
        LANDMARKS[key] = val - V((0, ROOT_Y, 0))
    elif isinstance(val, (list, tuple)):
        LANDMARKS[key] = type(val)(p - V((0, ROOT_Y, 0)) for p in val)
norm = Matrix.Translation((0, -ROOT_Y, 0)) @ norm0
for o in meshes:
    o.data.transform(Matrix.Translation((0, -ROOT_Y, 0)))


# --- armature ---------------------------------------------------------------------------------------

L = LANDMARKS
mir = lambda p: V((-p.x, p.y, p.z))
BONES = []  # (name, head, tail, parent, z_axis_hint, deform)


def add(name, h, t, parent, up, deform=True):
    BONES.append((name, V(h), V(t), parent, V(up), deform))


FWD, UP = (0, -1, 0), (0, 0, 1)
sp = L["spine"]
add("pelvis", sp[0], sp[1], None, FWD)
add("spine", sp[1], sp[2], "pelvis", FWD)
add("chest", sp[2], sp[3], "spine", FWD)
nk = L["neck"]
add("neck0", nk[0], nk[1], "chest", FWD)
add("neck1", nk[1], nk[2], "neck0", FWD)
add("head", nk[2], L["snout"], "neck1", UP)
add("jaw", L["jaw"][0], L["jaw"][1], "head", UP)
for side, f in (("L", lambda p: V(p)), ("R", mir)):
    a = [f(p) for p in L["arm"]]
    add(f"clav_{side}", a[0], a[1], "chest", UP)
    add(f"upperarm_{side}", a[1], a[2], f"clav_{side}", UP)
    add(f"forearm_{side}", a[2], a[3], f"upperarm_{side}", UP)
    add(f"hand_{side}", a[3], a[4], f"forearm_{side}", UP)
    add(f"hand_tgt_{side}", a[3], a[3] + (a[4] - a[3]) * 0.5, "chest", UP, deform=False)
    add(f"elbow_pole_{side}", a[2] + V((f(V((14, 0, 0))).x, 30, -6)), a[2] + V((f(V((14, 0, 0))).x, 34, -6)),
        "chest", UP, deform=False)
    g = [f(p) for p in L["leg"]]
    add(f"thigh_{side}", g[0], g[1], "pelvis", FWD)
    add(f"shin_{side}", g[1], g[2], f"thigh_{side}", FWD)
    add(f"meta_{side}", g[2], g[3], f"shin_{side}", FWD)
    add(f"toe_{side}", g[3], g[4], f"meta_{side}", UP)
    add(f"foot_ctrl_{side}", g[3], g[4], None, UP, deform=False)
    add(f"knee_pole_{side}", g[1] + V((0, -40, 0)), g[1] + V((0, -45, 0)), "pelvis", UP, deform=False)
tail = resample(L["tail"], TAIL_BONES)
for i in range(TAIL_BONES):
    add(f"tail{i}", tail[i], tail[i + 1], "pelvis" if i == 0 else f"tail{i - 1}", UP)

ROLLS = {}
arm_data = bpy.data.armatures.new("KaijuRig")
rig = bpy.data.objects.new("KaijuRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, h, t, parent, up, deform in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    eb.align_roll(up)
    ROLLS[name] = eb.roll
    eb.use_deform = deform
    if parent:
        eb.parent = arm_data.edit_bones[parent]
        eb.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
REST = {b.name: b.matrix_local.copy() for b in arm_data.bones}
DEFORM = [b for b in BONES if b[5]]
NAMES = [b[0] for b in DEFORM]
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"

for side in ("L", "R"):
    ik = rig.pose.bones[f"meta_{side}"].constraints.new("IK")
    ik.target, ik.subtarget = rig, f"foot_ctrl_{side}"
    ik.pole_target, ik.pole_subtarget = rig, f"knee_pole_{side}"
    ik.chain_count = 3
    cr = rig.pose.bones[f"toe_{side}"].constraints.new("COPY_ROTATION")
    cr.target, cr.subtarget = rig, f"foot_ctrl_{side}"
    ik = rig.pose.bones[f"forearm_{side}"].constraints.new("IK")
    ik.target, ik.subtarget = rig, f"hand_tgt_{side}"
    ik.pole_target, ik.pole_subtarget = rig, f"elbow_pole_{side}"
    ik.chain_count = 2


def pick_pole_angle(owner, joint):
    """Per side, the pole angle that keeps the knee or elbow where it was built (depends on roll)."""
    for side in ("L", "R"):
        con = rig.pose.bones[f"{owner}_{side}"].constraints["IK"]
        best = None
        for deg in range(-180, 180, 5):
            con.pole_angle = math.radians(deg)
            bpy.context.view_layer.update()
            err = (rig.pose.bones[f"{joint}_{side}"].head - REST[f"{joint}_{side}"].translation).length
            if best is None or err < best[1]:
                best = (deg, err)
        con.pole_angle = math.radians(best[0])
        print(f"{owner}_{side} pole angle {best[0]} deg, {joint} error at rest {best[1]:.3f} m")


pick_pole_angle("meta", "shin")
pick_pole_angle("forearm", "forearm")


# --- weights: nearest bone in its region, clean falloff into parent and child, then smoothed --------

CHAIN_NEXT = {"pelvis": "spine", "spine": "chest", "chest": "neck0", "neck0": "neck1", "neck1": "head"}
for side in ("L", "R"):
    CHAIN_NEXT.update({f"clav_{side}": f"upperarm_{side}", f"upperarm_{side}": f"forearm_{side}",
                       f"forearm_{side}": f"hand_{side}", f"thigh_{side}": f"shin_{side}",
                       f"shin_{side}": f"meta_{side}", f"meta_{side}": f"toe_{side}"})
for i in range(TAIL_BONES - 1):
    CHAIN_NEXT[f"tail{i}"] = f"tail{i + 1}"
PARENT = {b[0]: b[3] for b in DEFORM}
BLEND_TO_PARENT = {n: p for n, p in PARENT.items() if p is not None}
FALLOFF = 0.4  # share of the shorter bone over which a joint blends


def side_of(name):
    return 1 if name.endswith("_L") else (-1 if name.endswith("_R") else 0)


def jaw_mask(obj, v):
    """Lower-jaw vertices. A: the Jaw object. B: below the mouth line, cut through the emptiest
    band of the open mouth in each slice in front of the hinge."""
    if MODEL == "A":
        return np.full(len(v), obj.name.startswith("Jaw"))
    hinge, tip = L["jaw"]
    if "mouth" in L:  # a measured tooth line: everything under it, above the throat, is jaw
        m0, m1 = L["mouth"]
        k_ = np.clip((v[:, 1] - hinge.y) / (tip.y - hinge.y), 0, 1)
        floor = (hinge.z - 7.0) + ((tip.z - 4.0) - (hinge.z - 7.0)) * k_
        line = m0.z + (m1.z - m0.z) * (v[:, 1] - m0.y) / (m1.y - m0.y)
        return (v[:, 1] > tip.y - 4) & (v[:, 1] < m1.y + 0.5) & (v[:, 2] < line) & (v[:, 2] > floor)             & (np.abs(v[:, 0]) < 9)
    mask = np.zeros(len(v), bool)
    for y0 in np.arange(tip.y - 3, hinge.y - 1, 1.0):
        sl = (np.abs(v[:, 1] - y0) < 0.5) & (np.abs(v[:, 0]) < 9) & (v[:, 2] > 76) & (v[:, 2] < 97)
        zs = np.sort(v[sl, 2])
        if len(zs) < 10:
            continue
        gaps = np.diff(zs)
        mid = (zs[:-1] + zs[1:]) / 2
        ok = (mid > 80) & (mid < 92)
        if not ok.any():
            continue
        k = np.argmax(np.where(ok, gaps, -1))
        cut = mid[k] if gaps[k] > 0.6 else hinge.z - (hinge.z - tip.z) * 0.5
        # Floor of the lower jaw: well under the mouth, never down into the throat.
        k_ = (y0 - hinge.y) / (tip.y - hinge.y)
        floor = (hinge.z - 7.0) + ((tip.z - 4.0) - (hinge.z - 7.0)) * min(1.0, max(0.0, k_))
        mask |= (np.abs(v[:, 1] - y0) < 0.5) & (v[:, 2] < cut) & (v[:, 2] > floor) & (np.abs(v[:, 0]) < 9)
    return mask


def mouth_z(y):
    """Height of the closed mouth's tooth line at y (models with a measured "mouth")."""
    m0, m1 = L["mouth"]
    return m0.z + (m1.z - m0.z) * (y - m0.y) / (m1.y - m0.y)


RIPS = {}  # per object: (head-side vertex ids, jaw-side copies) along the ripped tooth line


def rip_mouth(obj):
    """A sealed Tripo mouth: the lips are one skin, so an opening jaw would stretch a curtain of faces
    across the gap. Tear the skin along the tooth line (render mesh only): faces whose centre is under
    the line in the mouth zone keep copies of the shared vertices; backfaces shade dark so the gap
    reads as a mouth interior. The game export keeps the welded (untorn) positions."""
    me = obj.data
    co = np.array([v.co for v in me.vertices])
    hinge, tip = L["jaw"]
    m1 = L["mouth"][1]
    def in_jaw(c):
        return abs(c[0]) < 9 and tip.y - 4 < c[1] < m1.y and c[2] < mouth_z(c[1])             and c[2] > (hinge.z - 7.0) + ((tip.z - 4.0) - (hinge.z - 7.0)) * min(1, max(0, (c[1] - hinge.y) / (tip.y - hinge.y)))
    jaw_face = [in_jaw(co[list(f.vertices)].mean(0)) for f in me.polygons]
    used = {}
    for f, jf in zip(me.polygons, jaw_face):
        for vi in f.vertices:
            used.setdefault(vi, set()).add(jf)
    tear = [vi for vi, k in used.items() if len(k) == 2 and co[vi, 1] < m1.y - 1]
    base = len(me.vertices)
    me.vertices.add(len(tear))
    new_of = {vi: base + k for k, vi in enumerate(tear)}
    for vi, ni in new_of.items():
        me.vertices[ni].co = me.vertices[vi].co
    for f, jf in zip(me.polygons, jaw_face):
        if jf:
            for li in f.loop_indices:
                vi = me.loops[li].vertex_index
                if vi in new_of:
                    me.loops[li].vertex_index = new_of[vi]
    me.update(calc_edges=True)
    me.validate()
    # Hard sides in front of the gape (the hinge keeps its blend): every vertex of a jaw face rides
    # the jaw, every other vertex in the mouth zone rides the skull.
    jaw_v, head_v = set(), set()
    for f, jf in zip(me.polygons, jaw_face):
        (jaw_v if jf else head_v).update(f.vertices)
    co = np.array([v.co for v in me.vertices])
    front = lambda vi: co[vi, 1] < m1.y - 4 and abs(co[vi, 0]) < 9
    RIPS[obj.name] = (np.array(sorted(v for v in head_v - jaw_v if front(v) and co[v, 2] > mouth_z(co[v, 1]) - 1),
                               dtype=np.int64),
                      np.array(sorted(v for v in jaw_v if front(v)), dtype=np.int64))
    for slot in obj.material_slots:
        nt = slot.material.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or not bsdf.inputs["Base Color"].is_linked:
            continue
        src = bsdf.inputs["Base Color"].links[0].from_socket
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["B"].default_value = (0.035, 0.008, 0.006, 1.0)
        nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
        nt.links.new(src, mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    print(f"mouth {obj.name}: tooth line torn at {len(tear)} vertices")


def seg(points, h, t):
    ab = t - h
    L2 = max(1e-9, ab @ ab)
    u = np.clip(((points - h) @ ab) / L2, 0, 1)
    return np.linalg.norm(points - (h + u[:, None] * ab), axis=1), u * math.sqrt(L2)


def islands(n, e):
    """Connected-component label per vertex (min-label propagation with pointer jumping)."""
    lab = np.arange(n)
    while True:
        m = np.minimum(lab[e[:, 0]], lab[e[:, 1]])
        new = lab.copy()
        np.minimum.at(new, e[:, 0], m)
        np.minimum.at(new, e[:, 1], m)
        new = new[new]
        if np.array_equal(new, lab):
            return lab
        lab = new


def weights_for(obj):
    me = obj.data
    v = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    v_all = v.reshape(-1, 3)
    # Weld by position: glTF splits vertices along UV seams; weighted apart, a seam opens a crack.
    _, first, weld = np.unique(np.round(v_all / 0.001).astype(np.int64), axis=0, return_index=True,
                               return_inverse=True)
    weld = weld.ravel()
    v = v_all[first]
    heads = {n: np.array(h) for n, h, *_ in DEFORM}
    tails = {n: np.array(t) for n, h, t, *_ in DEFORM}
    lens = {n: np.linalg.norm(tails[n] - heads[n]) for n in NAMES}
    dist = np.zeros((len(v), len(NAMES)))
    along = np.zeros_like(dist)
    jaw = jaw_mask(obj, v)
    for j, n in enumerate(NAMES):
        d, a = seg(v, heads[n], tails[n])
        sd = side_of(n)
        if sd:
            d = d + np.where(v[:, 0] * sd > -0.5, 0, 1e4)
        if n == "jaw":
            d = d + np.where(jaw, 0, 1e4)
        elif n != "head":
            d = d + np.where(jaw, 1e4, 0)
        dist[:, j], along[:, j] = d, a
    near = np.argmin(dist, axis=1)
    W = np.zeros_like(dist)
    idx = {n: j for j, n in enumerate(NAMES)}
    rows = np.arange(len(v))
    a = along[rows, near]
    W[rows, near] = 1.0
    for j, n in enumerate(NAMES):
        sel = near == j
        if not sel.any():
            continue
        p = BLEND_TO_PARENT.get(n)
        if p:
            zone = FALLOFF * min(lens[n], lens[p])
            wp = 0.5 * np.clip(1 - a[sel] / zone, 0, 1)
            W[np.where(sel)[0], idx[p]] += wp
            W[np.where(sel)[0], j] -= wp
        c = CHAIN_NEXT.get(n)
        if c:
            zone = FALLOFF * min(lens[n], lens[c])
            wc = 0.5 * np.clip(1 - (lens[n] - a[sel]) / zone, 0, 1)
            W[np.where(sel)[0], idx[c]] += wc
            W[np.where(sel)[0], j] -= wc
    # Smooth over the surface: seams between chains (arm/chest, thigh/belly) get a soft edge.
    e = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", e)
    e = weld[e.reshape(-1, 2)]
    e = e[e[:, 0] != e[:, 1]]
    deg = np.bincount(e.ravel(), minlength=len(v)).astype(float)[:, None]
    for _ in range(6):
        acc = np.zeros_like(W)
        np.add.at(acc, e[:, 0], W[e[:, 1]])
        np.add.at(acc, e[:, 1], W[e[:, 0]])
        W = np.where(deg > 0, 0.5 * W + 0.5 * acc / np.maximum(deg, 1), W)
    # Loose parts (spikes, scutes, teeth, Tripo's floating bits) move rigidly with the body vertex
    # nearest them: weighted on their own they pick their own bone and drift off the hide.
    comp = islands(len(v), e)
    sizes = np.bincount(comp)
    main = sizes[comp] >= 0.2 * len(v)
    if (~main).any() and main.any():
        mi = np.nonzero(main)[0]
        for c in np.unique(comp[~main]):
            members = np.nonzero(comp == c)[0]
            cen = v[members].mean(0)
            # The anchor: the main-body vertex nearest the island (its base on the hide).
            near_i = mi[np.argmin(np.linalg.norm(v[mi] - cen, axis=1))]
            hinge, tip = L["jaw"]
            k_ = min(1.0, max(0.0, (cen[1] - hinge.y) / (tip.y - hinge.y)))
            if "mouth" in L and abs(cen[0]) < 9 and tip.y - 4 < cen[1] < L["mouth"][1].y                     and abs(cen[2] - mouth_z(cen[1])) < 4:
                W[members] = 0.0  # a tooth: rigid with the jaw its centre sits on
                W[members, idx["jaw" if cen[2] < mouth_z(cen[1]) else "head"]] = 1.0
            elif jaw[members].all() and len(members) > 100 and cen[2] > hinge.z + (tip.z - hinge.z) * k_ + 0.5:
                W[members] = 0.0  # the palate: a slab above the mouth line rides the skull
                W[members, idx["head"]] = 1.0
            elif not jaw[members].any() or jaw[near_i]:
                W[members] = W[near_i]
        print(f"islands {obj.name}: {len(np.unique(comp[~main]))} loose parts rigged to the hide")
    # Four influences at most, normalised.
    top = np.argsort(-W, axis=1)[:, 4:]
    np.put_along_axis(W, top, 0, axis=1)
    W /= np.maximum(1e-9, W.sum(1, keepdims=True))
    print(f"welded {obj.name}: {len(v_all)} -> {len(v)} positions")
    WELDED[obj.name] = (v.copy(), W.copy())
    W, v, jaw = W[weld], v_all, jaw[weld]
    if obj.name in RIPS:  # the torn lips: each side rides its own jaw, nothing spans the gap
        head_side, jaw_side = RIPS[obj.name]
        W[head_side] = 0.0
        W[head_side, NAMES.index("head")] = 1.0
        W[jaw_side] = 0.0
        W[jaw_side, NAMES.index("jaw")] = 1.0
    groups = {n: obj.vertex_groups.new(name=n) for n in NAMES}
    for j, n in enumerate(NAMES):
        nz = np.nonzero(W[:, j] > 0.002)[0]
        g = groups[n]
        for i, w in zip(nz.tolist(), W[nz, j].tolist()):
            g.add([i], w, "REPLACE")
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    obj.parent = rig
    print(f"weights {obj.name}: {len(v)} verts, jaw verts {int(jaw.sum())}")
    return v, W


REST_V = {}
WEIGHTS = {}
WELDED = {}  # per object: unique positions and their weights (what the game samples)
for o in meshes:
    if "mouth" in L:
        rip_mouth(o)
    REST_V[o.name], WEIGHTS[o.name] = weights_for(o)


# --- keys ---------------------------------------------------------------------------------------------

def world_q(pitch=0.0, yaw=0.0, roll=0.0):
    """A rotation about world axes (degrees): pitch about X (+ = forward / nose down; for a bone
    pointing back, the tail, + lifts it), yaw about
    Z (+ = toward the kaiju's left), roll about Y."""
    return Euler((math.radians(pitch), math.radians(roll), math.radians(yaw)), "ZXY").to_quaternion()


def set_rot(name, q):
    """Pose a bone by a rotation given in rest armature axes, relative to its parent."""
    r = REST[name].to_quaternion()
    rig.pose.bones[name].rotation_quaternion = r.inverted() @ q @ r


def set_loc(name, delta):
    """Move a bone's head by delta (rest armature axes)."""
    rig.pose.bones[name].location = REST[name].to_quaternion().inverted() @ V(delta)


hip_h = L["leg"][0].z
# Stride per cycle (adult ~46.7 m: 3 cycles travel 140 m = 7 checker periods, so the render loops) and
# frames per cycle (a whole number of cycles in the 144-frame clip, so the walk loops seamlessly);
# a model's landmarks may set its own (a cub's quick short steps, an adolescent's long ones).
D = L.get("stride", 140.0 / 3)
T = L.get("cycle", 48.0)
DUTY = 0.62
V_WALK = D / T
# A model may set its feet wider than its rest leg ("splay", metres out from the body: a sprawl that
# steps outside the belly seen from the game's high camera) and lift them higher ("lift", x hip height).
SPLAY = V((L.get("splay", 0.0), 0, 0))
BALL = {s: (L["leg"][3] + SPLAY if s == "L" else mir(L["leg"][3] + SPLAY)) for s in ("L", "R")}
LIFT = L.get("lift", 0.085)
PHASE = {"L": 0.0, "R": 0.5}


def path(clip):
    """Root position (x, y) and yaw (deg) for frames -80..FRAMES+80."""
    out = {}
    pos = V((0, 0, 0))
    start = -80
    for f in range(start, FRAMES + 81):
        if clip == "walk":
            yaw, speed = 0.0, V_WALK
        elif clip == "turn":
            t = min(1.0, max(0.0, (f - 30) / 78))
            yaw = 90.0 * (t * t * (3 - 2 * t))
            speed = V_WALK * (1 - 0.25 * math.sin(math.pi * t))
        else:
            yaw, speed = 0.0, 0.0
        out[f] = (pos.copy(), yaw)
        pos += Quaternion((0, 0, 1), math.radians(yaw)) @ V((0, -speed, 0))
    base = out[0][0].copy()
    return {f: (p - base, y) for f, (p, y) in out.items()}


def foot_world(clip, side, f, P):
    """World position and yaw of a foot's ball: planted for the stance, arcing through the swing."""
    rest = BALL[side]
    if clip in ("roar", "idle"):
        return rest, 0.0, 0.0, True
    c = f / T - PHASE[side]
    k = math.floor(c)
    u = c - k

    def plant(kk):
        tm = int(round((kk + DUTY / 2 + PHASE[side]) * T))
        tm = max(min(tm, FRAMES + 80), -80)
        p, yaw = P[tm]
        return p + Quaternion((0, 0, 1), math.radians(yaw)) @ rest, yaw

    if u < DUTY:
        p, yaw = plant(k)
        return p, yaw, 0.0, True
    s_ = (u - DUTY) / (1 - DUTY)
    p0, y0 = plant(k)
    p1, y1 = plant(k + 1)
    e = s_ * s_ * (3 - 2 * s_)
    # Lift and toe pitch go as sin^2: the foot arrives with no downward speed (no snap at contact).
    lift = math.sin(math.pi * s_) ** 2
    p = p0.lerp(p1, e) + V((0, 0, LIFT * hip_h * lift))
    return p, y0 + (y1 - y0) * e, 16.0 * lift, False


# Tail motion (degrees per joint, base -> tip: base + extra * k, k = 0 at the root, 1 at the tip).
TAIL_WALK = (1.0, 2.5)  # the walk's side-to-side S-wave
TAIL_WALK_PERIOD = L.get("tail_strides", 1.75) * T  # frames per tail wave: seven strides carry four
WALK_CYCLES = 7  # the baked walk: whole strides and whole tail waves (tail_strides divides 7), so it loops
TAIL_IDLE = (0.4, 0.2)  # the standing sway (72-frame period; at 0.6 in the roar)
TAIL_LAG = 0.42  # phase (rad) each joint trails the one before (0.6 of a wave along the tail)
TAIL_DRAG = (1.5, 3.0)  # turn: degrees per joint at the turn's peak rate, swung to the outside
TAIL_DRAG_TAU = 0.3  # s: how far the drag lags the body's turn rate (it eases in and out)
TAIL_WHIP_DELAY = 0.5  # frames the whip takes per joint
TAIL_LIFT = (6.0, -9.0)  # roar: the lift's arc per joint (root rises, mid curves up, tip trails)
TAIL_SLAM = (1.15, 0.85)  # roar: the slam per joint as it lands, then where it rests, x (0.2 + 1.6 k)
TAIL_TRAIL = 12.0  # roar: how far the outer tail curls up as the slam starts (per joint, x k)
TAIL_SLAM_DELAY = 0.8  # frames the lift and the slam take per joint (the tip lands after the mid-tail)
TAIL_SPRING = (14.0, 0.36)  # the tail's natural frequency (rad/s) and damping ratio
_WHIP = {}
# The roar's recovery (frames): about a second after the slam it returns to standing.
ROAR_REST = (71, 99)


def tail_drag(clip, P):
    """The tail's drag in a turn, by frame, -1..1: the body's turn rate (from the clip's path) through
    a first-order lag, so the tail swings out late, after the body starts turning, and eases back
    after it stops; positive (outward) for a left turn (lead review: no early curl into the turn, no
    snap back)."""
    if clip not in _WHIP:
        rate = {f: (P[f + 1][1] - P[f - 1][1]) * 0.5 for f in range(min(P) + 1, max(P))}
        top = max(abs(v) for v in rate.values()) or 1.0
        k = 1.0 - math.exp(-1.0 / (FPS * TAIL_DRAG_TAU))
        x, out = 0.0, {}
        for f in sorted(rate):
            x += (rate[f] / top - x) * k
            out[f] = x
        _WHIP[clip] = out
    return _WHIP[clip]


def lagged(series, t):
    """A per-frame series read at a fractional frame (linear between frames)."""
    f0 = math.floor(t)
    a, b = series.get(f0, 0.0), series.get(f0 + 1, 0.0)
    return a + (b - a) * (t - f0)


def pose_frame(clip, f, P):
    root, yaw = P[f]
    rig.location = root
    rig.rotation_mode = "XYZ"
    rig.rotation_euler = (0, 0, math.radians(yaw))
    ph = 2 * math.pi * f / T
    walking = clip in ("walk", "turn")
    def ramp(a, b, x):
        t = min(1.0, max(0.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    roar = 1.0 if clip == "roar" else 0.0
    gait = 1.0 if walking else 0.0
    if clip == "turn":  # the game turns standing: the body's walking sway dies once the turn is done
        gait *= 1 - ramp(100, 116, f)
    idle = 1.0 if clip == "idle" else 0.0  # the game's standing loop: breathing only
    # Roar beats (24 fps): settle 0-14; coil 14-38 (the head dips first and is already lifting while
    # the pelvis still sinks, so the motion never stalls); rear 31-47 (one ease in and out, fastest
    # about f39); then a slow drift (eased in) through a one-second hold after the slam, and the
    # recovery ROAR_REST (back to standing, so the game's roar ends soon after the slam). Nothing in
    # the roar moves faster than the breathing and the look: no tremor layer (a 7 Hz shake buzzed).
    windup = ramp(12, 28, f) * (1 - ramp(27, 40, f)) * roar   # head and neck coil (bottoms first)
    drop = ramp(22, 38, f) * (1 - ramp(37, 45, f)) * roar     # pelvis and knees load, fastest as the head turns
    # The drift starts as the rear ends (eased in: no frozen peak, no speed step), builds steadily and
    # overlaps the recovery, so nothing stops between them.
    d_ = max(0.0, f - 47.0)
    drift = (d_ * d_ / 12.0 if d_ < 6 else d_ - 3.0) / 68.0  # 6-frame ease, then steady (no cap: no kink)
    rear = ramp(31, 47, f) * (1 - 0.45 * drift) * (1 - ramp(*ROAR_REST, f)) * roar
    # Breathing at a period that divides the clip (72 frames), so the roar loops without a pop.
    breathe = math.sin(f * 2 * math.pi / 72) * (roar + idle)
    # One slow pulse at the peak (f55-73, about 0.7 Hz): the jaw snaps wider and the chest pushes, then
    # settles, so the peak is a second bellow rather than a statue.
    pulse = (math.sin(math.pi * (f - 55) / 18.0) ** 2 if 55 <= f <= 73 else 0.0) * roar
    # A slow look across the street through the drift (head and tail), gone by the recovery.
    look = math.sin(math.pi * min(1.0, max(0.0, (f - 46) / 50.0))) * math.sin(2 * math.pi * (f - 46) / 50.0) * roar
    # Walk: pelvis bobs twice a cycle and shifts its weight over the stance foot; the chest drifts
    # after it and counter-turns; the tail sways against the hips.
    w = ph - math.pi * DUTY  # 0 = left foot mid-stance
    # Weight lands on each contact: a short dip in the frames after a foot plants.
    land = 0.0
    for phs in PHASE.values():
        d = ((f / T - phs) % 1.0) * T  # frames since this foot's contact
        land += math.sin(math.pi * d / 10.0) ** 2 if d < 10.0 else 0.0  # sin^2: no velocity step
    bounce = L.get("bounce", 1.0)  # how high the body bobs on each step (a cub bounces)
    bob = (-0.016 * bounce * hip_h * math.cos(2 * ph) * gait - 0.012 * hip_h * land * gait
           - 0.18 * hip_h * drop + 0.035 * hip_h * rear + 0.012 * hip_h * breathe + 0.015 * hip_h * pulse)
    sway = 0.045 * hip_h * math.cos(w) * gait
    set_loc("pelvis", (sway, 0, bob))
    p_yaw = 4.0 * math.sin(ph) * gait
    p_roll = 3.0 * math.cos(w) * gait
    set_rot("pelvis", world_q(pitch=-7 * rear + 9 * drop, yaw=p_yaw, roll=p_roll))
    set_rot("spine", world_q(pitch=1.2 * math.sin(2 * ph - 0.5) * gait - 10 * rear + 4 * windup,
                             yaw=-0.6 * p_yaw, roll=-0.6 * p_roll))
    set_rot("chest", world_q(pitch=-0.8 * math.sin(2 * ph - 1.0) * gait - 9 * rear + 3 * windup + 1.5 * breathe - 4.0 * pulse,
                             yaw=-0.7 * p_yaw + 2.0 * math.sin(ph - 0.8) * gait,
                             roll=-0.8 * p_roll + 1.5 * math.cos(w - 0.8) * gait))
    # Neck and head keep the hunting gaze steady (counter the body), a little low when walking;
    # in the roar the head dips through the wind-up, then throws back.
    set_rot("neck0", world_q(pitch=4 * gait + 1.2 * math.sin(2 * ph - 1.4) * gait - 15 * rear + 24 * windup - 2.0 * pulse,
                             yaw=-0.25 * p_yaw - 1.0 * math.sin(ph - 1.2) * gait))
    set_rot("neck1", world_q(pitch=2 * gait - 11 * rear + 15 * windup, yaw=-0.25 * p_yaw))
    set_rot("head", world_q(pitch=-1.4 * math.sin(2 * ph - 1.4) * gait - 16 * rear + 15 * windup
                            + 2.0 * breathe - 2.0 * pulse, yaw=7.0 * look))
    # Mouth shut at rest and walking; it parts in the wind-up and gapes at the peak.
    set_rot("jaw", world_q(pitch=L.get("jaw_rest", 0.0) + 5 * windup + 36.0 * rear + 9.0 * pulse))
    # Arms: elbows bent, hands low in front of the belly; at the peak the claws come up to the chest,
    # elbows still bent (never out forward); no shoulder roll.
    sp1 = L["spine"][1]
    for side, sg in (("L", 1), ("R", -1)):
        swing = 2.5 * math.sin(ph + (0 if side == "L" else math.pi)) * gait
        set_rot(f"clav_{side}", world_q())
        rest_wrist = REST[f"hand_tgt_{side}"].translation
        if "hands" in L:  # offsets from the rest wrist (short arms reach these)
            lo, hi = L["hands"]["low"], L["hands"]["high"]
            low = rest_wrist + V((-sg * lo[0], lo[1] + 0.5 * swing, lo[2]))
            high = rest_wrist + V((-sg * hi[0], hi[1], hi[2]))
        else:
            low = V((sg * 9.0, sp1.y - L["belly"] + 0.5 * swing, sp1.z + 2.0))
            high = V((sg * 13.0, sp1.y - L["belly"] + 2.0, sp1.z + 12.0))
        set_loc(f"hand_tgt_{side}", low.lerp(high, rear) - rest_wrist)
        set_rot(f"hand_{side}", world_q(pitch=25 - 10 * rear))
    # Tail (director 2026-10-18: a heavy, mobile tail). Walk and idle: a wave travels root to tip,
    # each joint a fixed phase behind the one before, so the tip sweeps about three times as far as
    # the end of the thick root third; the idle keeps a slow sway that never stops. Turn: the tail's
    # mass drags it to the outside of the turn, lagging the body's turn rate (tail_drag()), and it
    # eases back once the body stops; the wave reaches the tip late.
    # Roar: lifted through the coil, slammed down at the peak (a wave down the tail), a rebound,
    # then it rests low until the recovery.
    whip = tail_drag(clip, P) if clip == "turn" else None
    for i in range(TAIL_BONES):
        k = i / (TAIL_BONES - 1)
        # The game turns standing: the turn clip's tail carries only the whip (no walk sway), so it
        # settles to the idle pose when the body stops.
        settle_t = 0.0 if clip == "turn" else 1.0
        walk_yaw = (TAIL_WALK[0] + TAIL_WALK[1] * k) * L.get("tail_sway", 1.0)
        walk_yaw *= math.cos(2 * math.pi * f / TAIL_WALK_PERIOD - math.pi * DUTY - TAIL_LAG * i) * gait * settle_t
        idle_yaw = (TAIL_IDLE[0] + TAIL_IDLE[1] * k) * math.sin(2 * math.pi * f / 72 - TAIL_LAG * i) * (idle + 0.6 * roar)
        turn_yaw = (TAIL_DRAG[0] + TAIL_DRAG[1] * k) * lagged(whip, f - TAIL_WHIP_DELAY * i) if whip else 0.0
        roar_yaw = (0.6 + 2.2 * k) * rear * (1 if i >= 2 else 0.3) - 1.2 * look * (i >= 3)
        # Lift: an arc, root first, the tip trailing; slam: a wave down the tail that speeds up into
        # the street (no ease at the bottom: it lands hard), a short bounce, then it rests low.
        lag = TAIL_SLAM_DELAY * i
        hit = 37 + lag
        fall = 5.0 - 3.0 * k  # the outer tail whips down fastest
        down = min(1.0, max(0.0, (f - hit + fall) / fall)) ** 2
        lift = ramp(10 + 1.5 * lag, 24 + 1.5 * lag, f) * (1 - down) * roar
        slam = down * (TAIL_SLAM[0] + (TAIL_SLAM[1] - TAIL_SLAM[0]) * ramp(hit + 2, hit + 10, f))
        slam *= (1 - ramp(*ROAR_REST, f)) * roar
        trail = ramp(31, 36, f) * (1 - down) * roar  # the outer tail trails up as the root drives down
        b = f - hit
        rebound = math.exp(-b / 3) * math.sin(math.pi * b / 4) * roar if b > 0 else 0.0
        # In the roar the base lifts against the pelvis tipping back, so the slam lands the tip just
        # above the street rather than through it.
        set_rot(f"tail{i}", world_q(yaw=walk_yaw + idle_yaw + turn_yaw + roar_yaw,
                                    pitch=0.6 * math.sin(2 * ph - TAIL_LAG * i) * gait * settle_t
                                    + L.get("tail_roar_lift", 2.5) * rear * (i < 2) - 0.3 * rear * (i >= 2)
                                    + 2.0 * windup * (i < 4) + L.get("tail_breathe", 0.4) * breathe
                                    + L.get("tail_lift", 0.0) * (i == 0)
                                    + (TAIL_LIFT[0] + TAIL_LIFT[1] * k) * lift + TAIL_TRAIL * k * trail - (0.2 + 1.6 * k) * (slam - 4.0 * TAIL_SLAM[1] * rebound)))
    # Feet: world-fixed while planted (converted into the moving rig's space).
    # The rig's matrix for this frame (rig.matrix_world still holds the last evaluated frame).
    inv = (Matrix.Translation(root) @ Matrix.Rotation(math.radians(yaw), 4, "Z")).inverted()
    rig_q = Quaternion((0, 0, 1), math.radians(yaw))
    for side in ("L", "R"):
        p, fyaw, pitch, _ = foot_world(clip, side, f, P)
        target = inv @ p
        r = REST[f"foot_ctrl_{side}"]
        rig.pose.bones[f"foot_ctrl_{side}"].location = r.to_quaternion().inverted() @ (target - r.translation)
        set_rot(f"foot_ctrl_{side}", world_q(yaw=fyaw - yaw) @ world_q(pitch=pitch))
    return rig_q


def key_clip(clip):
    if rig.animation_data:
        rig.animation_data_clear()
    P = path(clip)
    for f in range(FRAMES):
        scene.frame_set(f)
        pose_frame(clip, f, P)
        rig.keyframe_insert("location", frame=f)
        rig.keyframe_insert("rotation_euler", frame=f)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    scene.frame_start, scene.frame_end = 0, FRAMES - 1
    return P


# --- scene ----------------------------------------------------------------------------------------------

scene.render.fps = FPS
scene.render.resolution_x, scene.render.resolution_y = RES
scene.render.engine = "BLENDER_EEVEE"
scene.world = bpy.data.worlds.new("sky")
scene.world.use_nodes = True
bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.55, 0.6, 0.68, 1)
bg.inputs[1].default_value = 0.8
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(48), 0, math.radians(35))
scene.collection.objects.link(sun)
bpy.ops.mesh.primitive_plane_add(size=6000)
ground = bpy.context.active_object
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
nt = gm.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
chk = nt.nodes.new("ShaderNodeTexChecker")
chk.inputs["Color1"].default_value = (0.36, 0.35, 0.33, 1)
chk.inputs["Color2"].default_value = (0.30, 0.29, 0.28, 1)
chk.inputs["Scale"].default_value = 600  # 10 m squares
tc = nt.nodes.new("ShaderNodeTexCoord")
nt.links.new(tc.outputs["Generated"], chk.inputs["Vector"])
nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
ground.data.materials.append(gm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.lens = 35
cam.data.clip_end = 5000
scene.collection.objects.link(cam)
scene.camera = cam
CAM_DIST = max(235.0, 1.25 * float(np.ptp(np.concatenate([REST_V[o.name][:, 1] for o in meshes]))))
VIEWS = {"side": V((-1, 0, 0.12)), "threeq": V((-0.75, -0.65, 0.32)),
         "high": V((-0.62, -0.55, 0.75))}  # high: front three-quarter about 45 deg down, like the game camera
RENDER_VIEWS = os.environ.get("MT_VIEWS", "side,threeq").split(",")


def place_camera(view, focus, far=1.0):
    d = VIEWS[view].normalized()
    cam.location = focus + d * CAM_DIST * far
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


# The roar rears the head well above standing height: frame higher and wider so the snout stays in.
ROAR_FOCUS, ROAR_FAR = V((0, 15, 60)), 1.15


def focus_of(P, f):
    p, _ = P[f]
    return V((p.x, p.y + 15, 48))


# --- tasks ----------------------------------------------------------------------------------------------

def settle(f):
    """Evaluate a frame twice: the IK solver starts from the last solve, so a jump between frames
    (a new clip, a skipped range) is only right on the second pass."""
    scene.frame_set(f)
    scene.frame_set(f)


def render(clip):
    P = key_clip(clip)
    for view in RENDER_VIEWS:
        d = OUT / f"{MODEL}_{clip}_{view}"
        d.mkdir(parents=True, exist_ok=True)
        for f in range(FRAMES):
            settle(f)
            place_camera(view, *((focus_of(P, f),) if clip in ("walk", "turn") else (ROAR_FOCUS, ROAR_FAR)))
            scene.render.filepath = str(d / f"{f:04d}.png")
            bpy.ops.render.render(write_still=True)
        print("rendered", d)


def sole_sets():
    """Per foot: the sole vertices (rest z < 2 m, mostly on toe/meta)."""
    out = {}
    for o in meshes:
        v, W = REST_V[o.name], WEIGHTS[o.name]
        for side in ("L", "R"):
            # Contact pads: the lowest toe vertices, the part that should stay put while planted.
            sel = np.nonzero((v[:, 2] < 1.2) & (W[:, NAMES.index(f"toe_{side}")] > 0.6))[0]
            if len(sel):
                out.setdefault(side, []).append((o, sel))
    return out


def measure(clip):
    P = key_clip(clip)
    soles = sole_sets()
    track = {s: [] for s in soles}
    deps = bpy.context.evaluated_depsgraph_get()
    for f in range(FRAMES):
        settle(f)
        deps = bpy.context.evaluated_depsgraph_get()
        for side, parts in soles.items():
            acc = []
            for o, sel in parts:
                me = o.evaluated_get(deps).to_mesh()
                co = np.empty(len(me.vertices) * 3)
                me.vertices.foreach_get("co", co)
                o.evaluated_get(deps).to_mesh_clear()
                co = co.reshape(-1, 3)[sel]
                acc.append((np.array(o.matrix_world) @ np.c_[co, np.ones(len(co))].T).T[:, :3])
            pts_ = np.concatenate(acc)
            track[side].append((f, pts_.mean(0).tolist(), float(pts_[:, 2].min())))
    plants = []
    for side in track:
        stance = [foot_world(clip, side, f, P)[3] for f in range(FRAMES)]
        f = 0
        while f < FRAMES:
            if stance[f]:
                g = f
                while g < FRAMES and stance[g]:
                    g += 1
                seg_ = track[side][f:g]
                if len(seg_) >= 4:
                    start = np.array(seg_[0][1][:2])
                    drift = max(np.linalg.norm(np.array(c[:2]) - start) for _, c, _ in seg_)
                    plants.append({"foot": side, "frames": [f, g - 1], "slide_cm": round(drift * 100, 1),
                                   "sole_min_z_cm": round(min(z for *_, z in seg_) * 100, 1)})
                f = g
            else:
                f += 1
    res = {"model": MODEL, "clip": clip, "plants": plants,
           "max_slide_cm": max([p["slide_cm"] for p in plants], default=0)}
    (OUT / f"{MODEL}_{clip}_footslide.json").write_text(json.dumps(res, indent=1))
    print("footslide", MODEL, clip, res["max_slide_cm"], "cm max over", len(plants), "plants")


def crops():
    """Close-ups at the most bent frames: shoulder and hips mid-walk, jaw at the roar's peak."""
    scene.render.resolution_x = scene.render.resolution_y = 700
    shots = [("walk", 39, "shoulder_L", "upperarm_L", V((-0.6, -0.8, 0.25)), 34),
             ("walk", 39, "hip_L", "thigh_L", V((-1, -0.25, 0.1)), 40),
             ("roar", 52, "jaw", "jaw", V((-0.85, -0.5, 0.2)), 36),
             ("roar", 52, "shoulder_L_roar", "upperarm_L", V((-0.5, -0.85, 0.2)), 34),
             # The tail root through the turn's whip: dragged wide, swung through at the stop, the
             # overshoot (from above and behind, where a pinch, a fin or a shear would show).
             ("turn", 39, "tail_root_drag", "tail1", V((-0.35, 0.6, 0.8)), 40),
             ("turn", 108, "tail_root_whip", "tail1", V((-0.35, 0.6, 0.8)), 40),
             ("turn", 117, "tail_root_over", "tail1", V((-0.35, 0.6, 0.8)), 40),
             # The roar's slam: the mid-tail as the tip lands (side on, where a kink would show).
             ("roar", 47, "tail_mid_slam", "tail5", V((-1, 0.1, 0.15)), 55)]
    cam.data.lens = 50
    for clip, f, label, bone, d, dist in [x for x in shots if x[0] in CLIPS]:
        key_clip(clip)
        settle(f)
        bpy.context.view_layer.update()
        c = rig.matrix_world @ rig.pose.bones[bone].head
        if label == "hip_L":
            c = c + V((8, 0, -6))
        if label == "jaw":
            c = rig.matrix_world @ rig.pose.bones[bone].center
        dd = d.normalized()
        cam.location = c + dd * dist * 2.2
        cam.rotation_euler = (-dd).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / f"{MODEL}_crop_{label}_f{f}.png")
        bpy.ops.render.render(write_still=True)


def tail_top(clip):
    """Top-down still of a clip's first frame with the paths the tail joints draw over the whole
    clip, in the body's own frame (root travel and yaw removed), laid over the body where it
    stands: the tip (orange) and the end of the thick root third (cyan)."""
    key_clip(clip)
    traces = {3: [], TAIL_BONES: []}
    for f in range(FRAMES):
        settle(f)
        for j in traces:
            b = rig.pose.bones[f"tail{min(j, TAIL_BONES - 1)}"]
            traces[j].append((b.tail if j == TAIL_BONES else b.head).copy())
    settle(0)
    bpy.context.view_layer.update()
    m = rig.matrix_world.copy()
    for j, rgb in ((3, (0.0, 0.85, 1.0)), (TAIL_BONES, (1.0, 0.42, 0.0))):
        cu = bpy.data.curves.new(f"trace{j}", "CURVE")
        cu.dimensions, cu.bevel_depth = "3D", 0.9
        sp = cu.splines.new("POLY")
        sp.points.add(len(traces[j]) - 1)
        for pt, p in zip(sp.points, traces[j]):
            q = m @ p
            pt.co = (q.x, q.y, 60.0, 1.0)  # drawn above the body
        sp.use_cyclic_u = clip in ("walk", "idle")
        mat = bpy.data.materials.new(f"trace{j}")
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = 4.0
        cu.materials.append(mat)
        scene.collection.objects.link(bpy.data.objects.new(f"trace{j}", cu))
    scene.render.resolution_x, scene.render.resolution_y = 640, 1000
    cam.data.type, cam.data.ortho_scale = "ORTHO", 310.0
    centre = m @ V((0, 62, 0))  # rig origin: under the pelvis
    cam.location = (centre.x, centre.y, 600.0)
    cam.rotation_euler = (0, 0, m.to_euler().z)
    scene.render.filepath = str(OUT / f"{MODEL}_{clip}_tailtop.png")
    bpy.ops.render.render(write_still=True)


def diff(clip):
    """Per-frame change of the pose: mean distance every vertex moves between frames, in the rig's
    own space (root travel removed), including the loop seam f(N-1) -> f0; and the tail tip's height."""
    key_clip(clip)
    deps = None
    prev = first = None
    steps, tip_z, head_tip = [], [], []
    tip = rig.pose.bones[f"tail{TAIL_BONES - 1}"]
    for f in range(FRAMES):
        settle(f)
        deps = bpy.context.evaluated_depsgraph_get()
        cos = []
        for o in meshes:
            me = o.evaluated_get(deps).to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            o.evaluated_get(deps).to_mesh_clear()
            cos.append(co.reshape(-1, 3))
        cur = np.concatenate(cos)
        if prev is not None:
            steps.append(float(np.linalg.norm(cur - prev, axis=1).mean()))
        else:
            first = cur
        prev = cur
        tip_z.append(float((rig.matrix_world @ tip.tail).z))
        head_tip.append(list(rig.matrix_world @ rig.pose.bones["head"].tail))
    seam = float(np.linalg.norm(first - prev, axis=1).mean())
    # Buzz check: sign flips of the snout tip's acceleration (a tremor flips every frame or two).
    acc = np.diff(np.array(head_tip), n=2, axis=0)
    out = dict(clip=clip, steps=steps, seam=seam, median=float(np.median(steps)), tail_tip_z=tip_z,
               head_tip=head_tip, head_accel=np.linalg.norm(acc, axis=1).tolist())
    (OUT / f"{MODEL}_{clip}_diff.json").write_text(json.dumps(out), encoding="utf-8")
    print(f"diff {MODEL} {clip}: median {out['median']:.3f} m/frame, max {max(steps):.3f} "
          f"(f{int(np.argmax(steps)) + 1}), seam {seam:.3f}; tail tip min z {min(tip_z):.1f} m")


def tail_stats(clip):
    """The tail through a clip, in the rig's own space (root travel and yaw removed): each joint's
    side-to-side sweep (half the range of x), the tip's path, each joint's bend from rest (deg, the
    worst frame), each joint's height and the lowest tail skin (world z, m), and the tip's angle off the
    body's long axis per frame (the turn's whip and settle)."""
    key_clip(clip)
    names = [f"tail{i}" for i in range(TAIL_BONES)]
    behind = L["tail"][0].y + 5.0  # tail skin: rest vertices behind the tail's first metres
    tail_v = {o.name: np.nonzero(REST_V[o.name][:, 1] > behind)[0] for o in meshes}
    xs, path_xy, bends, low_joint, low_skin, tip_angle, joint_z = [], [], [], [], [], [], []
    for f in range(FRAMES):
        settle(f)
        pts = [rig.pose.bones[n].head.copy() for n in names] + [rig.pose.bones[names[-1]].tail.copy()]
        xs.append([p.x for p in pts])
        path_xy.append([[p.x, p.y] for p in pts])
        bends.append([math.degrees(rig.pose.bones[n].rotation_quaternion.angle) for n in names])
        joint_z.append([(rig.matrix_world @ p).z for p in pts])
        low_joint.append(min(joint_z[-1]))
        deps = bpy.context.evaluated_depsgraph_get()
        low = 1e9
        for o in meshes:
            if len(tail_v[o.name]):
                me = o.evaluated_get(deps).to_mesh()
                co = np.empty(len(me.vertices) * 3)
                me.vertices.foreach_get("co", co)
                o.evaluated_get(deps).to_mesh_clear()
                low = min(low, float((np.array(rig.matrix_world) @ np.c_[co.reshape(-1, 3)[tail_v[o.name]],
                                     np.ones(len(tail_v[o.name]))].T)[2].min()))
        low_skin.append(low)
        d = pts[-1] - pts[0]
        tip_angle.append(math.degrees(math.atan2(d.x, d.y)))
    xs = np.array(xs)
    sweep = ((xs.max(0) - xs.min(0)) / 2).tolist()
    out = dict(clip=clip, sweep_m=sweep, tip_over_root=sweep[-1] / max(sweep[1], 1e-6),
               max_bend_deg=np.array(bends).max(0).tolist(), low_joint_z=low_joint, low_skin_z=low_skin,
               tip_angle_deg=tip_angle, path_xy=path_xy, joint_z=joint_z)
    (OUT / f"{MODEL}_{clip}_tail.json").write_text(json.dumps(out), encoding="utf-8")
    print(f"tail {MODEL} {clip}: sweep root {sweep[1]:.2f} m tip {sweep[-1]:.2f} m "
          f"(x{out['tip_over_root']:.1f}); worst bend {max(out['max_bend_deg']):.1f} deg; "
          f"lowest joint {min(low_joint):.1f} m, skin {min(low_skin):.1f} m")


JOINTS = {"shoulder_L": "upperarm_L", "elbow_L": "forearm_L", "wrist_L": "hand_L", "hip_L": "thigh_L",
          "knee_L": "shin_L", "ankle_L": "meta_L", "neck": "neck1", "skull": "head", "jaw_hinge": "jaw",
          "tail_base": "tail1", "tail_mid": "tail5"}


def volume(clip):
    """Girth kept at each joint: vertices within reach of the joint at rest, their mean distance
    to the posed joint centre each frame against rest. A collapsing (pinching) joint drops below
    100%; the worst frame is reported. A candy-wrapper twist shows up the same way."""
    P = key_clip(clip)
    sets = {}
    for j, bone in JOINTS.items():
        b = arm_data.bones[bone]
        c = np.array(b.head_local)
        near = min(np.linalg.norm(REST_V[o.name] - c, axis=1).min() for o in meshes)
        r = near + 0.5 * min(b.length, b.parent.length if b.parent else b.length)  # a shell round the joint
        for o in meshes:
            sel = np.nonzero(np.linalg.norm(REST_V[o.name] - c, axis=1) < r)[0]
            if len(sel):
                sets.setdefault(j, []).append((o, sel))
    rest = {}
    worst = {j: (9.9, -1) for j in sets}
    for f in [-1] + list(range(FRAMES)):
        if f < 0:
            for pb in rig.pose.bones:  # rest pose
                pb.matrix_basis = Matrix.Identity(4)
            for con in [c for pb in rig.pose.bones for c in pb.constraints]:
                con.mute = True
            bpy.context.view_layer.update()
        else:
            if f == 0:
                for con in [c for pb in rig.pose.bones for c in pb.constraints]:
                    con.mute = False
            settle(f)
        deps = bpy.context.evaluated_depsgraph_get()
        cos = {}
        for o in meshes:
            me = o.evaluated_get(deps).to_mesh()
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get("co", co)
            o.evaluated_get(deps).to_mesh_clear()
            cos[o.name] = co.reshape(-1, 3)  # objects sit at identity under the rig's space
        for j, parts in sets.items():
            centre = np.array(rig.pose.bones[JOINTS[j]].head)
            pts = np.concatenate([cos[o.name][sel] for o, sel in parts])
            g = np.linalg.norm(pts - centre, axis=1).mean()
            if f < 0:
                rest[j] = g
            elif g / rest[j] < worst[j][0]:
                worst[j] = (g / rest[j], f)
    res = {j: {"girth_kept_pct": round(100 * w, 1), "frame": fr} for j, (w, fr) in worst.items()}
    (OUT / f"{MODEL}_{clip}_volume.json").write_text(json.dumps(res, indent=1))
    print("volume", MODEL, clip, {j: float(v["girth_kept_pct"]) for j, v in res.items()})


GAME = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])  # blender (x, y, z) -> game (-x, z, y), det +1


def to_game3(p):
    return (GAME @ np.asarray(p, float).T).T


def game_bone(name):
    """Today's KaijuRig bone (rig_voxel names) that drives this bone, agreed with kaiju-voxel-skin:
    no counterpart -> the nearest ancestor's game bone; the 10-bone tail folds its last two into
    tail8. Sides: our _L is blender +x, rig_voxel's _l (game -x)."""
    sd = {"_L": "l", "_R": "r"}.get(name[-2:], "")
    fixed = {"pelvis": "spine0", "spine": "spine1", "chest": "spine2", "neck0": "head0", "neck1": "head0",
             "head": "head1", "jaw": "jaw"}
    if name in fixed:
        return fixed[name]
    if name.startswith("tail"):
        return f"tail{min(int(name[4:]), 8)}"
    base = name[:-2]
    return {"clav": "spine2", "upperarm": f"arm_{sd}0", "forearm": f"arm_{sd}1", "hand": f"arm_{sd}2",
            "thigh": f"leg_{sd}0", "shin": f"leg_{sd}1", "meta": f"leg_{sd}2", "toe": f"leg_{sd}2"}[base]


def export(height_vox):
    """The rig and welded weights for the game's voxel skin (format agreed with kaiju-voxel-skin).
    <stem>.skin.json: bones (deform only, parents first) with rest head/tail and basis in game axes
    (metres, Y up, -Z forward, origin on the ground under the pelvis), plus the matrix that takes a
    rig_voxel .kvox cell (gx, gy, gz) of the same GLB at height_vox to its centre in this space.
    <stem>.skinw: "KSKW", u32 version 1, u32 N, u16 bone count, then N x {f32 xyz, u8 bone[4],
    f32 weight[4]} (32 bytes), welded positions, weights sorted, summing to 1, unused = 255 / 0."""
    stem = Path(SRC).stem
    bones = []
    for b in arm_data.bones:
        if not b.use_deform:
            continue
        basis = np.array(b.matrix_local.to_3x3())  # columns: the bone's x, y (along), z axes
        bones.append({"name": b.name, "game": game_bone(b.name), "parent": b.parent.name if b.parent else None,
                      "head": to_game3(b.head_local).round(4).tolist(),
                      "tail": to_game3(b.tail_local).round(4).tolist(),
                      "basis": (GAME @ basis).T.round(5).tolist(),  # rows: x, y, z axes
                      "roll_blender": round(float(ROLLS[b.name]), 5),
                      "physics": b.name.startswith("tail"), "jaw": b.name == "jaw"})
    names = [b["name"] for b in bones]
    pos, wts = [], []
    for o in meshes:
        v, W = WELDED[o.name]
        pos.append(v)
        wts.append(W)
    pos, W = np.concatenate(pos), np.concatenate(wts)
    order = np.argsort(-W, axis=1)[:, :4]
    top = np.take_along_axis(W, order, axis=1)
    top /= np.maximum(1e-9, top.sum(1, keepdims=True))
    idx = np.array([names.index(n) for n in NAMES])[order].astype(np.uint8)
    idx[top <= 0] = 255
    top[top <= 0] = 0
    g = to_game3(pos).astype(np.float32)
    rec = np.zeros(len(g), dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])
    rec["p"], rec["b"], rec["w"] = g, idx, top.astype(np.float32)
    with open(OUT / f"{stem}.skinw", "wb") as f:
        f.write(b"KSKW" + np.array([1, len(g)], "<u4").tobytes() + np.array([len(names)], "<u2").tobytes())
        f.write(rec.tobytes())
    # rig_voxel's cell -> source point: k = (-(gx + 1), gz, gy); src = (k + 0.5) / sc + origin,
    # origin = (bbox centre x, bbox centre y, min z), sc = (height_vox - 1) / source height.
    sc = (height_vox - 1) / (SRC_HI[2] - SRC_LO[2])
    origin = np.array([(SRC_LO[0] + SRC_HI[0]) / 2, (SRC_LO[1] + SRC_HI[1]) / 2, SRC_LO[2]])
    def cell_to_skin(gc):
        k = np.array([-(gc[0] + 1), gc[2], gc[1]], float)
        src = (k + 0.5) / sc + origin
        bl = np.array(norm @ V(src))
        return to_game3(bl)
    o0 = cell_to_skin((0, 0, 0))
    M = np.eye(4)
    for i in range(3):
        e = [0, 0, 0]
        e[i] = 1
        M[:3, i] = cell_to_skin(e) - o0
    M[:3, 3] = o0
    gmin, gmax = to_game3(np.concatenate([REST_V[o.name] for o in meshes])).min(0),         to_game3(np.concatenate([REST_V[o.name] for o in meshes])).max(0)
    doc = {"version": 1, "units": "m", "axes": "game: Y up, -Z forward, x = -blender x; origin on the "
           "ground under the pelvis; model normalised to 100 m tall", "height_m": 100.0,
           "source": stem, "bones": bones, "vertex_count": int(len(g)),
           "weights_file": f"{stem}.skinw", "bbox_game": [gmin.round(3).tolist(), gmax.round(3).tolist()],
           "kvox_height": height_vox,
           "kvox_cell_to_skin": M.round(6).tolist(),
           "kvox_note": "p_skin = M @ (gx, gy, gz, 1): centre of a rig_voxel cell of the SAME glb at "
                        "kvox_height. rig_voxel bakes the jaw shut by a few degrees: jaw cells sit "
                        "turned from rest; sample them against jaw-weighted positions."}
    # LF on every OS: the game's skin stamp hashes these bytes (a CRLF copy read as stale).
    (OUT / f"{stem}.skin.json").write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")
    print(f"exported {stem}: {len(names)} bones, {len(g)} welded positions -> {OUT}")


# The game rig's bones (tools/kaiju_skin/rig_from_skin.py GAME_BONES, rig.json order).
GAME_BONES = ["spine0", "spine1", "spine2", "head0", "head1", "arm_l0", "arm_l1", "arm_l2", "leg_l0",
              "leg_l1", "leg_l2", "arm_r0", "arm_r1", "arm_r2", "leg_r0", "leg_r1", "leg_r2"] + [
              f"tail{i}" for i in range(9)] + ["jaw"]
# Clips the game plays: name -> (motion_test clip, frames kept, loops). The walk keeps one 48-frame
# cycle and the idle one 72-frame breath (both loop seamlessly); turn_right is turn_left mirrored.
GAME_CLIPS = [("idle", "idle", 72, True), ("walk", "walk", int(WALK_CYCLES * T), True), ("turn_left", "turn", 144, False),
              ("turn_right", "turn", 144, False), ("roar", "roar", 108, False)]
Q16 = 32767.0  # int16 scale of a quaternion component (positions are stored in cm)


def game_chains():
    """Each game bone's Blender chain, first (root) and last bone, as rig_from_skin builds it: a bone
    whose head sits on the chain's tail extends it (neck0 + neck1 = head0, meta + toe = leg_x2)."""
    first, last = {}, {}
    for b in arm_data.bones:
        if not b.use_deform:
            continue
        g = game_bone(b.name)
        first.setdefault(g, b)
        if g not in last or (b.parent is not None and b.parent.name == last[g].name
                             and (b.head_local - last[g].tail_local).length < 1e-3):
            last[g] = b
    return first, last


def game_pose(first, last):
    """The game bones' local rotations (game axes, x y z w) and the pelvis offset (game axes, metres)
    for the rig's current pose, in place (the rig object's travel and yaw left out). Every game bone
    rests with an identity basis, so a bone's world turn is its first Blender bone's turn, swung so
    its head->tail reaches the posed tail of its last bone; local = parent's world^-1 x world."""
    G = Matrix(GAME.tolist())
    world, quats = {}, []  # quats in GAME_BONES order
    for g in GAME_BONES:
        f, l = rig.pose.bones[first[g].name], rig.pose.bones[last[g].name]
        turn = (f.matrix.to_quaternion() @ first[g].matrix_local.to_quaternion().inverted())
        rest_dir = last[g].tail_local - first[g].head_local
        posed_dir = l.tail - f.head
        swing = (turn @ rest_dir).rotation_difference(posed_dir)
        w = (G @ (swing @ turn).to_matrix() @ G.transposed()).to_quaternion()
        world[g] = w
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        local = (world[pg].inverted() @ w) if pg else w
        quats.append(local.normalized())
    off = G @ (rig.pose.bones["pelvis"].head - arm_data.bones["pelvis"].head_local)
    return quats, off


def fk_error(first, last, qs, off):
    """Rebuilds the game skeleton from the local turns (as the game will) and returns the worst
    distance of a game bone's head or tail from the posed Blender joint it stands for (metres, joint)."""
    G = Matrix(GAME.tolist())
    world, head, worst = {}, {}, (0.0, "")
    for g, q in zip(GAME_BONES, qs):
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        rest_h = G @ first[g].head_local
        if pg is None:
            world[g], head[g] = q, rest_h + off
        else:
            world[g] = world[pg] @ q
            head[g] = head[pg] + world[pg] @ (rest_h - G @ first[pg].head_local)
        tail = head[g] + world[g] @ (G @ (last[g].tail_local - first[g].head_local))
        want_h = G @ rig.pose.bones[first[g].name].head
        want_t = G @ rig.pose.bones[last[g].name].tail
        worst = max(worst, ((head[g] - want_h).length, g + " head"), ((tail - want_t).length, g + " tail"))
    return worst


def mirror_frame(rec):
    """turn_right from turn_left: swap the sides and mirror across the game's x (YZ plane)."""
    qs, off, feet, contact, yaw, travel = rec
    idx = {g: i for i, g in enumerate(GAME_BONES)}
    swap = lambda g: g.replace("_l", "_R").replace("_r", "_l").replace("_R", "_r")
    mq = [None] * len(GAME_BONES)
    for g in GAME_BONES:
        q = qs[idx[swap(g)]]
        mq[idx[g]] = Quaternion((q.w, q.x, -q.y, -q.z))
    m = lambda v: V((-v.x, v.y, v.z))
    return mq, m(off), [m(feet[1]), m(feet[0])], [contact[1], contact[0]], -yaw, m(travel)


def clips_export():
    """<stem>.kclip for the game's clip player (scenes/kaiju_clips.gd): "KCLP", u32 version 1, u32
    header length, the header (JSON: game bones in rig.json order and the skin bones each gathers,
    their rest heads, fps, the walk's stride per cycle, the clip table), then every clip's frames:
    27 x int16[4] local quaternion (x y z w, /32767), int16[3] pelvis offset, int16[6] left then
    right toe tip (rig space, cm), int16 root yaw (centidegrees), int16[2] root travel (x z, dm; unused by the game),
    u8 contacts (bit 0 left, 1 right), u8 pad: 242 bytes a frame. Game axes, metres x 100."""
    import struct
    first, last = game_chains()
    G = Matrix(GAME.tolist())
    gathers = {g: [b.name for b in arm_data.bones if b.use_deform and game_bone(b.name) == g] for g in GAME_BONES}
    heads = {g: list(round(x, 3) for x in G @ first[g].head_local) for g in GAME_BONES}
    body, table, start, worst = bytearray(), [], 0, (0.0, "", "")
    recorded = {}
    for name, clip, n, loop in GAME_CLIPS:
        if clip not in recorded:
            P = key_clip(clip)
            frames = []
            for f in range(FRAMES):
                settle(f)
                qs, off = game_pose(first, last)
                worst = max(worst, fk_error(first, last, qs, off) + (f"{clip} f{f}",))
                # Game left (_l, -x) is our _L (blender +x).
                feet = [G @ rig.pose.bones[f"toe_{s}"].tail for s in ("L", "R")]
                contact = [foot_world(clip, s, f, P)[3] for s in ("L", "R")]
                root, yaw = P[f]
                frames.append((qs, off, feet, contact, yaw, G @ root))
            recorded[clip] = frames
        frames = recorded[clip][:n]
        if name == "turn_right":
            frames = [mirror_frame(r) for r in frames]
        for qs, off, feet, contact, yaw, travel in frames:
            for q in qs:
                body += struct.pack("<4h", *(int(round(c * Q16)) for c in (q.x, q.y, q.z, q.w)))
            cm = lambda v: [int(round(c * 100.0)) for c in v]  # metres -> cm
            body += struct.pack("<3h", *cm(off))
            body += struct.pack("<6h", *(cm(feet[0]) + cm(feet[1])))
            body += struct.pack("<h", int(round(yaw * 100)))
            body += struct.pack("<2h", *(int(round(c * 10.0)) for c in (travel.x, travel.z)))  # dm
            body += struct.pack("<BB", (1 if contact[0] else 0) | (2 if contact[1] else 0), 0)
        table.append({"name": name, "first": start, "frames": n, "loop": loop,
                      "cycles": round(n / T) if clip == "walk" else 1})
        start += n
    header = json.dumps({"version": 1, "fps": FPS, "frame_bytes": 242, "bones": GAME_BONES,
                         "gathers": gathers, "rest_heads_m": heads, "stride_m": round(D, 4),
                         "body_height_m": 100.0, "clips": table, "source": Path(SRC).name},
                        separators=(",", ":")).encode()
    out = OUT / f"{Path(SRC).stem}.kclip"
    out.write_bytes(b"KCLP" + struct.pack("<II", 1, len(header)) + header + bytes(body))
    print(f"clips {out.name}: {len(table)} clips, {start} frames, {out.stat().st_size} bytes; "
          f"worst game-joint error vs the Blender pose {worst[0]:.3f} m ({worst[1]}, {worst[2]})")


def fit_sheet():
    """Bones drawn over the mesh (see-through), side and front, orthographic, 10 m checker ground:
    <out>/<stem>_fit_side.png, _fit_front.png. Look at these before trusting an auto fit."""
    stem = Path(SRC).stem
    red = bpy.data.materials.new("bone")
    red.use_nodes = True
    em = red.node_tree.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1, 0.1, 0.05, 1)
    em.inputs["Strength"].default_value = 3
    out_n = next(n for n in red.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    red.node_tree.links.new(em.outputs[0], out_n.inputs["Surface"])
    for b in arm_data.bones:
        if not b.use_deform:
            continue
        h, t = b.head_local, b.tail_local
        bpy.ops.mesh.primitive_cylinder_add(radius=0.7, depth=(t - h).length, location=(h + t) / 2)
        c = bpy.context.active_object
        c.rotation_mode = "QUATERNION"
        c.rotation_quaternion = (t - h).to_track_quat("Z", "Y")
        c.data.materials.append(red)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.4, location=h)
        bpy.context.active_object.data.materials.append(red)
    for o in meshes:
        o.modifiers.clear()
        for slot in o.material_slots:
            m = slot.material
            if m is None:
                continue
            m.surface_render_method = "BLENDED"
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf:
                bsdf.inputs["Alpha"].default_value = 0.3
    ground.hide_render = True
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 190
    scene.render.resolution_x = scene.render.resolution_y = 900
    for name, d in (("side", V((-1, 0, 0))), ("front", V((0, -1, 0)))):
        cam.location = V((0, 10, 50)) + d * 400
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(OUT / f"{stem}_fit_{name}.png")
        bpy.ops.render.render(write_still=True)
    print("fit sheet", OUT / f"{stem}_fit_side.png")


def fit_report():
    """Auto landmarks against the hand-measured ones (only for A and B), then the fit sheet."""
    if MODEL not in KNOWN:
        print("fit: no hand landmarks to compare for", MODEL)
        fit_sheet()
        return
    try:
        auto = auto_landmarks(all_vertices() + np.array([0, ROOT_Y, 0]))  # same frame as KNOWN
    except (AttributeError, ValueError, IndexError) as e:
        print(f"fit {MODEL}: auto landmarks failed on this body plan ({e}); hand pivots used")
        fit_sheet()
        return
    hand = KNOWN[MODEL]
    rows = []
    for k in ("spine", "neck", "arm", "leg", "jaw"):
        for i, (a_, h_) in enumerate(zip(auto[k], hand[k])):
            rows.append((f"{k}[{i}]", round((V(a_) - V(h_)).length, 1)))
    rows.append(("snout", round((auto["snout"] - hand["snout"]).length, 1)))
    rows.append(("belly", round(auto["belly"] - hand["belly"], 1)))
    print("fit", MODEL, "auto vs hand (m):", rows)
    for k in ("spine", "neck", "leg"):
        print(" ", k, "auto", [tuple(round(c, 1) for c in p) for p in auto[k]])
        print(" ", k, "hand", [tuple(round(c, 1) for c in p) for p in hand[k]])
    (OUT / f"{MODEL}_fit.json").write_text(json.dumps({"auto_minus_hand_m": rows}, indent=1))
    fit_sheet()


if TASK == "export":
    export(int(CLIPS[0]) if CLIPS[0].isdigit() else 160)
elif TASK == "fit":
    fit_report()
elif TASK == "volume":
    for c in CLIPS:
        volume(c)
elif TASK == "render":
    for c in CLIPS:
        render(c)
elif TASK == "measure":
    for c in CLIPS:
        measure(c)
elif TASK == "crops":
    crops()
elif TASK == "clips":
    clips_export()
elif TASK == "diff":
    for c in CLIPS:
        diff(c)
elif TASK == "tail":
    for c in CLIPS:
        tail_stats(c)
elif TASK == "tailtop":
    tail_top(CLIPS[0])
elif TASK == "blend":
    key_clip(CLIPS[0])
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{MODEL}_motion_test.blend"))
elif TASK == "still":
    for c in CLIPS:
        P = key_clip(c)
        for f in ((0, 13, 26, 39, 60, 80) if c != "roar" else (10, 32, 40, 52, 85, 125)):
            scene.frame_set(f)
            for view in RENDER_VIEWS:
                place_camera(view, *((focus_of(P, f),) if c != "roar" else (ROAR_FOCUS, ROAR_FAR)))
                scene.render.filepath = str(OUT / f"{MODEL}_{c}_{view}_f{f:03d}.png")
                bpy.ops.render.render(write_still=True)
