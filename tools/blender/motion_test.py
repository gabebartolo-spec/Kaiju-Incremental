"""Motion test: one hand-built armature, fitted to a kaiju mesh at its real pivots, scripted weights
with clean joint falloff, and three keyed clips (walk, 90 degree turn, roar). Answers "is bad motion
the mesh or the rig?" by running the same rig and keys on two meshes (A: our Blender reptile,
B: the Tripo adult).

    blender -b --python tools/blender/motion_test.py -- <A|B> <in.glb> <out_dir> <task> [clips]

task: render (PNG frames per clip and view), measure (foot slide JSON), crops (joint close-ups),
blend (save the rigged, keyed .blend). clips: comma list of walk,turn,roar (default all). Run one clip per Blender process: re-keying a
second clip in the same process left the first frame posed from the old action.
Units: metres, every model normalised to 100 m tall, snout at y = 0, facing -Y, feet on z = 0.
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
FPS, FRAMES = 24, 144
RES = (640, 480)


# --- landmarks (the real pivots, measured on each mesh; left side, right is mirrored) -------------

def a_pt(x, y, z):
    """A was built in its own frame (build_reptile.py); normalised = (y + 51.517) * 0.99397."""
    k = 0.99397
    return V((x * k, (y + 51.517) * k, z * k))


LANDMARKS = {
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
}[MODEL]
TAIL_BONES = 10
# Re-origin on the pelvis' ground point: the rig turns about the hips, not the snout.
ROOT_Y = LANDMARKS["spine"][0].y
for key, val in LANDMARKS.items():
    if isinstance(val, V):
        LANDMARKS[key] = val - V((0, ROOT_Y, 0))
    elif isinstance(val, (list, tuple)):
        LANDMARKS[key] = type(val)(p - V((0, ROOT_Y, 0)) for p in val)


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
lo, hi = pts.min(0), pts.max(0)
s = 100.0 / (hi[2] - lo[2])
norm = Matrix.Translation((0, -ROOT_Y, 0)) @ Matrix.Scale(s, 4) @ Matrix.Translation((-(lo[0] + hi[0]) / 2, -lo[1], -lo[2]))
for o in meshes:
    o.parent = None
    o.data.transform(norm @ world[o.name])
    o.matrix_world = Matrix.Identity(4)
for o in [o for o in scene.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o)


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

arm_data = bpy.data.armatures.new("KaijuRig")
rig = bpy.data.objects.new("KaijuRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, h, t, parent, up, deform in BONES:
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = h, t
    eb.align_roll(up)
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
    v = v.reshape(-1, 3)
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
    e = e.reshape(-1, 2)
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
            if not jaw[members].any() or jaw[near_i]:
                W[members] = W[near_i]
        print(f"islands {obj.name}: {len(np.unique(comp[~main]))} loose parts rigged to the hide")
    # Four influences at most, normalised.
    top = np.argsort(-W, axis=1)[:, 4:]
    np.put_along_axis(W, top, 0, axis=1)
    W /= np.maximum(1e-9, W.sum(1, keepdims=True))
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
for o in meshes:
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
D = 0.95 * 46.0  # stride per cycle, the same for both meshes so the paths match
T = 52.0  # frames per cycle
DUTY = 0.62
V_WALK = D / T
BALL = {s: (L["leg"][3] if s == "L" else mir(L["leg"][3])) for s in ("L", "R")}
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
    if clip == "roar":
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
    p = p0.lerp(p1, e) + V((0, 0, 0.075 * hip_h * math.sin(math.pi * s_)))
    return p, y0 + (y1 - y0) * e, 16.0 * math.sin(math.pi * s_), False


def pose_frame(clip, f, P):
    root, yaw = P[f]
    rig.location = root
    rig.rotation_mode = "XYZ"
    rig.rotation_euler = (0, 0, math.radians(yaw))
    ph = 2 * math.pi * f / T
    walking = clip != "roar"
    # Roar envelope: crouch (20-40), rear and open (40-60), hold (60-108), recover (108-140).
    def ramp(a, b, x):
        t = min(1.0, max(0.0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    crouch = ramp(18, 38, f) * (1 - ramp(40, 56, f)) if not walking else 0.0
    rear = ramp(40, 58, f) * (1 - ramp(106, 136, f)) if not walking else 0.0
    shake = math.sin(f * 2 * math.pi * 7 / FPS) * (ramp(58, 64, f) * (1 - ramp(100, 108, f))) if not walking else 0.0
    gait = 1.0 if walking else 0.0
    # Pelvis: bob twice a cycle, sway over the stance foot, slight yaw and roll.
    bob = -0.016 * hip_h * math.cos(2 * ph) * gait - 0.05 * hip_h * crouch + 0.03 * hip_h * rear
    sway = 0.025 * hip_h * math.cos(ph - math.pi * DUTY) * gait
    set_loc("pelvis", (sway, 0, bob))
    p_yaw = 3.0 * math.sin(ph) * gait
    set_rot("pelvis", world_q(pitch=-6 * rear + 4 * crouch, yaw=p_yaw, roll=2.0 * math.cos(ph - math.pi * DUTY) * gait))
    set_rot("spine", world_q(pitch=1.0 * math.sin(2 * ph) * gait - 9 * rear + 5 * crouch, yaw=-0.5 * p_yaw))
    set_rot("chest", world_q(pitch=-0.6 * math.sin(2 * ph) * gait - 7 * rear + 3 * crouch, yaw=-0.4 * p_yaw))
    # Neck and head steady the gaze (the hunting head): counter the body, a little low when walking.
    set_rot("neck0", world_q(pitch=4 * gait - 14 * rear + 8 * crouch + 0.8 * shake, yaw=-0.3 * p_yaw))
    set_rot("neck1", world_q(pitch=2 * gait - 10 * rear + 6 * crouch, yaw=-0.3 * p_yaw))
    set_rot("head", world_q(pitch=-0.5 * math.sin(2 * ph) * gait - 18 * rear + 6 * crouch + 1.2 * shake))
    set_rot("jaw", world_q(pitch=4.0 * gait + 34.0 * rear * (1 + 0.04 * shake) - 3 * crouch))
    # Arms hang with bent elbows, hands low near the belly; no shoulder roll; a small swing.
    for side, sg in (("L", 1), ("R", -1)):
        swing = 3.0 * math.sin(ph + (0 if side == "L" else math.pi)) * gait
        set_rot(f"clav_{side}", world_q())
        # IK hand target: low in front of the belly (riding the chest); spread and raised to roar.
        sp1 = L["spine"][1]
        low = V((sg * 9.0, sp1.y - L["belly"] + 0.5 * swing, sp1.z + 2.0))
        high = V((sg * 24.0, sp1.y - L["belly"] - 4.0, sp1.z + 14.0))
        rest_wrist = REST[f"hand_tgt_{side}"].translation
        set_loc(f"hand_tgt_{side}", low.lerp(high, rear) - rest_wrist)
        set_rot(f"hand_{side}", world_q(pitch=25 - 30 * rear))
    # Tail: a wave that runs to the tip against the hips, lifted when he rears.
    for i in range(TAIL_BONES):
        amp = (1.2 + 0.45 * i) * gait
        set_rot(f"tail{i}", world_q(yaw=-amp * math.sin(ph - 0.5 * i),
                                    pitch=0.6 * math.sin(2 * ph - 0.45 * i) * gait + 3.0 * rear * (i < 4) + 1.0 * rear * (i >= 4)
                                    + 2.0 * crouch))
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
VIEWS = {"side": V((-1, 0, 0.12)), "threeq": V((-0.75, -0.65, 0.32))}


def place_camera(view, focus):
    d = VIEWS[view].normalized()
    cam.location = focus + d * 235
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


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
    for view in VIEWS:
        d = OUT / f"{MODEL}_{clip}_{view}"
        d.mkdir(parents=True, exist_ok=True)
        for f in range(FRAMES):
            settle(f)
            place_camera(view, focus_of(P, f) if clip != "roar" else V((0, 15, 48)))
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
             ("roar", 80, "jaw", "jaw", V((-0.85, -0.5, 0.2)), 36),
             ("roar", 80, "shoulder_L_roar", "upperarm_L", V((-0.5, -0.85, 0.2)), 34)]
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


if TASK == "volume":
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
elif TASK == "blend":
    key_clip(CLIPS[0])
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"{MODEL}_motion_test.blend"))
elif TASK == "still":
    for c in CLIPS:
        P = key_clip(c)
        for f in (0, 13, 26, 39, 60, 80):
            scene.frame_set(f)
            for view in VIEWS:
                place_camera(view, focus_of(P, f) if c != "roar" else V((0, 15, 48)))
                scene.render.filepath = str(OUT / f"{MODEL}_{c}_{view}_f{f:03d}.png")
                bpy.ops.render.render(write_still=True)
