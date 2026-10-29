"""Bakes one Cascadeur-keyed move of the croc adult3 rig (r11; D-199, D-216: creature motion is keyed in Cascadeur, tail
and jaw layered in Blender, D-228) into the adult croc's .kclip (scenes/kaiju_clips.gd; layout in
tools/blender/motion_test.py clips_export()): per frame the 27 game bones' local turns, the pelvis offset, both toe tips
and the planted bits, in the croc_adult3_export.py frame (turned to face -Y, 100 m tall, origin on the ground under the
pelvis).
    blender -b <move>.blend --python tools/blender/croc_adult3_clips.py -- <x.kclip> <name> <first> <frames> <mode>         [<hit> <trail from> <trail to>]
<first> and <frames> are keyed frames (30 fps), <first> counted from the blend's first frame. A missing <x.kclip> is
started at 30 fps (header from the rig); an existing one keeps its fps (the Blender clips' 24): the keys are resampled to
it (turns slerped, points blended between the two nearest keyed frames), and a clip of the same name is replaced. Modes:
- still: in place as keyed (idle, roar, death, the rise from the bay); loops when <name> is "idle".
- walk: one looping cycle; the root travels the cycle's pelvis travel at an even pace and is taken out, so the clip walks
  in place and the game's step clock moves the body (header stride_m = that travel).
- turn: a turn on the spot; the root yaw is the pelvis heading (stored per frame, the game turns the body by it) and is
  taken out of the pose. The mirrored turn is appended too (turn_left <-> turn_right).
- layer: in place as keyed, played over the other clips on the arms and torso (ClipRake: the claw rake, D-185); its
  entry carries "layer": true, the hit frame (the claw crosses the snout line, where the sim's rake lands) and the
  trail's first and last frames (the streak, D-243), given as keyed frames from <first> and stored as clip frames.
  The mirrored rake is appended too (rake_r <-> rake_l).
A foot is planted while its toe tip is within PLANT_UP of its rest height and moves under PLANT_SLIDE to the next frame
(world): from the keyed contact until the toe tip peels off (the walk's stance, as the game locks the toe tip).
r12 (D-307): every rig tail joint is its own game bone (croc_adult3_export.py), so the clips carry the tail tip's own
turns (tail9-11) and the hind toes' (leg_x3), after the 27 r11 bones; the four eyelid bones (lid_lo_l/_r, lid_up_l/_r)
follow (D-335 blinks), then the two collar bones (clavicle_l/_r, lead 2026-10-28 call A: the shrug of the Cascadeur
rise; before, they folded into spine2 and the game's shoulder missed the keyed one by up to 2.04 m). A file of fewer
bones is upgraded on the way: its clips get still tip, toe, lid and collar bones (each turned as its parent, which is
what the old fold did), so a clip not re-baked plays exactly as before.
The adult's keyed clips so far (director-approved; sources in C:/Users/DANTE/cascadeur_bridge/croc_new/rig11/, keys
croc_<move>_<tag>.casc), added to the Blender clips' file:
    roar roar_intro/roar_c.blend 12 124 still | rise_bay roar_intro/rise_p.blend 0 120 still |
    death_stagger stagger/stagger_a.blend 20 41 still"""
import bpy, sys, json, math, re, struct
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector as V

a = sys.argv[sys.argv.index("--") + 1:]
OUT, NAME, FIRST, N, MODE = Path(a[0]), a[1], int(a[2]), int(a[3]), a[4]
assert MODE in ("still", "walk", "turn", "layer"), MODE
MARKS = [float(x) for x in a[5:8]]  # layer: hit, trail from, trail to (keyed frames from FIRST)
assert MODE != "layer" or len(MARKS) == 3, "layer needs <hit> <trail from> <trail to>"
KEYED_FPS = 30
PLANT_UP = 0.1  # m (100 m model): toe tip height over its rest height that still counts as down
PLANT_SLIDE = 0.5  # m a keyed frame: a planted toe tip holds still (the peel moves it 0.25, a swing metres)
BASE_BONES = ["spine0", "spine1", "spine2", "head0", "head1", "arm_l0", "arm_l1", "arm_l2", "leg_l0", "leg_l1", "leg_l2",
              "arm_r0", "arm_r1", "arm_r2", "leg_r0", "leg_r1", "leg_r2"] + [f"tail{i}" for i in range(9)] + ["jaw"]
IDENTITY = struct.pack("<4h", 0, 0, 0, 32767)
MIRROR = {"turn_left": "turn_right", "turn_right": "turn_left", "rake_r": "rake_l", "rake_l": "rake_r"}
arm = bpy.data.objects["croc_rig"]; ad = arm.data
mesh = bpy.data.objects["croc_mesh"]; me = mesh.data
scene = bpy.context.scene
F0 = scene.frame_start
assert F0 + FIRST + N - 1 <= scene.frame_end, f"{NAME}: frames past the blend's end {scene.frame_end}"
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
    if n.startswith("lid_"):  # eyelids keep their rig names (croc_adult3_export.py)
        return n
    if n.startswith("tail"):
        return f"tail{int(n[4:])}"
    return {"clavicle": f"clavicle_{sd}", "upperarm": f"arm_{sd}0", "forearm": f"arm_{sd}1", "hand": f"arm_{sd}2",
            "thigh": f"leg_{sd}0", "shin": f"leg_{sd}1", "foot": f"leg_{sd}2", "toe": f"leg_{sd}3"}[n[:-2]]


# The rest frame of croc_adult3_export.py: the mesh at rest without the lid flaps, 100 m tall, origin under the pelvis.
flaps = {g.index for g in mesh.vertex_groups if g.name.startswith("lid_lo")}
P = [R @ mesh.matrix_world @ v.co for v in me.vertices if not any(x.group in flaps and x.weight > 0 for x in v.groups)]
LO = V([min(p[i] for p in P) for i in range(3)]); HI = V([max(p[i] for p in P) for i in range(3)])
S = 100.0 / (HI.z - LO.z)
C = V(((LO.x + HI.x) / 2, LO.y, LO.z))
AW = R @ arm.matrix_world
ROOT_Y = ((AW @ ad.bones["pelvis"].head_local).y - C.y) * S
skin = lambda p: G3 @ ((V(tuple(p)) - C) * S - V((0.0, ROOT_Y, 0.0)))

deform = [b for b in ad.bones if b.use_deform and not HELPER(b.name)]
# The rig's own game bones follow, in the order they were added, then by chain and number (rig_from_skin.py
# extra_order and bone_names, so the rig.json and the clips list the bones in one order).
LATER = ("lid_", "clavicle_")
EXTRA = lambda n: (next((i + 1 for i, p in enumerate(LATER) if n.startswith(p)), 0), n.rstrip("0123456789"),
                   int(n[len(n.rstrip("0123456789")):] or 0))
GAME_BONES = BASE_BONES + sorted({game_bone(b.name) for b in deform} - set(BASE_BONES), key=EXTRA)
first, last = {}, {}
for b in deform:  # parents first; a bone starting on the chain's end extends it (neck0..2 = head0; r12: the toe is leg_x3)
    g = game_bone(b.name)
    first.setdefault(g, b)
    if g not in last or (b.parent is not None and b.parent.name == last[g].name
                         and (b.head_local - last[g].tail_local).length < 1e-4):
        last[g] = b
assert set(first) == set(GAME_BONES), set(GAME_BONES) ^ set(first)
# GAME_BONES is not parents first (a collar bone follows the arm it carries): the FK below walks this order instead.
TOPO = [game_bone(b.name) for b in deform if first[game_bone(b.name)] is b]
heads = {g: skin(AW @ first[g].head_local) for g in GAME_BONES}
REST_TOE = [skin(AW @ ad.bones[f"toe_{s}"].tail_local).y for s in ("l", "r")]


def world_pose():
    """Game bones' world turns (game axes, vs rest), the pelvis head and both toe tips (skin metres)."""
    world = {}
    for g in GAME_BONES:
        f, l = arm.pose.bones[first[g].name], arm.pose.bones[last[g].name]
        turn = f.matrix.to_quaternion() @ first[g].matrix_local.to_quaternion().inverted()
        rest_dir = last[g].tail_local - first[g].head_local
        swing = (turn @ rest_dir).rotation_difference(l.tail - f.head)
        world[g] = (M3 @ (swing @ turn).to_matrix() @ M3.transposed()).to_quaternion()
    pelvis = skin(AW @ arm.pose.bones["pelvis"].head)
    feet = [skin(AW @ arm.pose.bones[f"toe_{s}"].tail) for s in ("l", "r")]
    return world, pelvis, feet


def fk_error(world, pelvis):
    """Worst distance (m) of a game bone's head or tail, rebuilt from the turns as the game does, from its Blender joint."""
    head, worst = {}, (0.0, "")
    for g in TOPO:  # parents first
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        h = head[g] = pelvis if pg is None else head[pg] + world[pg] @ (heads[g] - heads[pg])
        t = h + world[g] @ (skin(AW @ last[g].tail_local) - heads[g])
        want_h = skin(AW @ arm.pose.bones[first[g].name].head)
        want_t = skin(AW @ arm.pose.bones[last[g].name].tail)
        worst = max(worst, ((h - want_h).length, g + " head"), ((t - want_t).length, g + " tail"))
    return worst


def heading(q):
    f = q @ V((0.0, 0.0, -1.0))
    return math.atan2(-f.x, -f.z)  # + = left (about game up)


if OUT.exists():
    data = OUT.read_bytes()
    hl = struct.unpack_from("<I", data, 8)[0]
    header, body = json.loads(data[12:12 + hl]), bytearray(data[12 + hl:])
    old = header["bones"]
    if old != GAME_BONES:  # an r11 file: its clips' tip bones stay as their parents turn (still, local identity)
        assert GAME_BONES[:len(old)] == old, f"{OUT.name}: bones {old} are not a prefix of {GAME_BONES}"
        fb, add = header["frame_bytes"], len(GAME_BONES) - len(old)
        cut = len(old) * 8
        body = bytearray(b"".join(body[k:k + cut] + IDENTITY * add + body[k + cut:k + fb]
                                  for k in range(0, len(body), fb)))
        header["bones"], header["frame_bytes"] = GAME_BONES, fb + add * 8
        header["gathers"] = {g: [b.name for b in deform if game_bone(b.name) == g] for g in GAME_BONES}
        header["rest_heads_m"].update({g: [round(c, 3) for c in heads[g]] for g in GAME_BONES[len(old):]})
        print(f"UPGRADED {OUT.name}: {len(old)} -> {len(GAME_BONES)} bones, {len(body) // header['frame_bytes']} frames")
    rest_gap = max((V(header["rest_heads_m"][g]) - heads[g]).length for g in GAME_BONES)
    assert rest_gap < 0.5, f"rest heads differ from {OUT.name}'s by {rest_gap:.3f} m"
else:
    gathers = {g: [b.name for b in deform if game_bone(b.name) == g] for g in GAME_BONES}
    header = {"version": 1, "fps": KEYED_FPS, "frame_bytes": len(GAME_BONES) * 8 + 26, "bones": GAME_BONES,
              "gathers": gathers, "rest_heads_m": {g: [round(c, 3) for c in heads[g]] for g in GAME_BONES},
              "stride_m": 1.0, "body_height_m": 100.0, "clips": [],
              "source": "croc adult3 rig r11, keyed in Cascadeur (tools/blender/croc_adult3_clips.py)"}
    body, rest_gap = bytearray(), 0.0
STEP = KEYED_FPS / header["fps"]  # keyed frames per clip frame
M = int(math.floor((N - 1) / STEP + 1e-6)) + 1  # clip frames


def sample(t):
    """The world pose at keyed frame t from FIRST (fractional: between the two nearest keyed frames) and the FK error
    of the lower one."""
    f0 = math.floor(t + 1e-9)
    k = t - f0
    scene.frame_set(F0 + FIRST + f0)
    w0, p0, ft0 = world_pose()
    err = fk_error(w0, p0)
    if k < 1e-6:
        return (w0, p0, ft0), err
    scene.frame_set(F0 + FIRST + f0 + 1)
    w1, p1, ft1 = world_pose()
    return ({g: w0[g].slerp(w1[g], k) for g in GAME_BONES}, p0.lerp(p1, k), [x.lerp(y, k) for x, y in zip(ft0, ft1)]), err


raw, worst = [], (0.0, "")
for i in range(-1, M + 1):  # one clip frame either side for the toe speeds
    t = i * STEP if MODE == "walk" else min(max(i * STEP, 0.0), (M - 1) * STEP)
    pose, err = sample(t)
    raw.append(pose)
    worst = max(worst, err)
yaw0 = heading(raw[1][0]["spine0"])
travel = V((0.0, 0.0, 0.0))
if MODE == "walk":
    travel = sample(float(N))[0][1] - raw[1][1]
    travel.y = 0.0
# Keys that walk forward from their frame 0 reach a later cycle whole strides down the path: that lead is taken out
# too (along the travel only, so the pelvis keeps its sway and surge), so the clip's pelvis sits over the sim's.
lead = V((0.0, 0.0, 0.0))
if MODE == "walk" and travel.length > 1e-6:
    d = travel.normalized()
    lead = d * (sum((raw[i + 1][1] - travel * (i / M) - heads["spine0"]).dot(d) for i in range(M)) / M)
frames, lows = [], []
for i in range(M):
    world, pelvis, feet = raw[i + 1]
    planted = []
    for s in range(2):
        up = feet[s].y - REST_TOE[s]
        slide = (raw[i + 2][2][s] - raw[i + 1][2][s]).xz.length
        planted.append(up < PLANT_UP and slide < PLANT_SLIDE * STEP)
    root = travel * (i / M)
    yaw = heading(world["spine0"]) - yaw0 if MODE == "turn" else 0.0
    yaw = math.atan2(math.sin(yaw), math.cos(yaw))
    inv = Quaternion((0.0, 1.0, 0.0), -yaw)
    quats = []
    for g in GAME_BONES:
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        quats.append(((world[pg].inverted() @ world[g]) if pg else (inv @ world[g])).normalized())
    off = inv @ (pelvis - root - lead) - heads["spine0"]
    toes = [inv @ (ft - root - lead) for ft in feet]
    frames.append((quats, off, toes, planted, math.degrees(yaw), root))
    lows.append("".join("L" if planted[0] else "-") + ("R" if planted[1] else "-"))
# Cascadeur can solve the same keys a little differently on the second stride, so a loop's last frame need not lead
# back into its first: the baby walk's knee snapped 10-24 deg at the seam. The mismatch (the frame after the last
# against the first) is eased out over the last SEAM clip frames.
SEAM = 20
if MODE == "walk" and M > 2 * SEAM:
    world, pelvis = raw[M + 1][0], raw[M + 1][1]
    end = []
    for g in GAME_BONES:
        par = first[g].parent
        pg = game_bone(par.name) if par is not None else None
        end.append(((world[pg].inverted() @ world[g]) if pg else world[g]).normalized())
    end_off = pelvis - travel - lead - heads["spine0"]
    gaps = [(frames[0][0][b] @ end[b].inverted()).normalized() for b in range(len(GAME_BONES))]
    worst_seam = max(min(q.angle, 2 * math.pi - q.angle) for q in gaps)

    def ramp(i, a, b):  # 0 before frame a, smoothstep up to 1 at frame b, 1 after
        s = min(max((i - a + 1) / (b - a + 1), 0.0), 1.0)
        return s * s * (3.0 - 2.0 * s)

    # A leg takes its mismatch (mostly the knee swinging about the hip-ankle line) from its last swing on, with the
    # ankle and foot kept where they were keyed, so a planted foot never slides (the baby's right foot was dragged in
    # stance, the walk's first second in game); the rest of the body eases over the last SEAM.
    window = {g: (M - SEAM, M) for g in GAME_BONES}
    for s, sd in enumerate(("l", "r")):
        e = M - 1
        while e > 0 and frames[e][3][s]:
            e -= 1
        a = e
        while a > 0 and not frames[a - 1][3][s]:
            a -= 1
        if 0 < a <= e:
            window.update({g: (a, e + 1) for g in GAME_BONES if g.startswith(f"leg_{sd}")})
            print(f"SEAM leg_{sd} eased over its swing f{a}-{e}")
    PARENT = {}
    for g in GAME_BONES:
        par = first[g].parent
        PARENT[g] = game_bone(par.name) if par is not None else None
    IDX = {g: b for b, g in enumerate(GAME_BONES)}

    def fk(qs, off, root=V((0.0, 0.0, 0.0))):  # world turns and heads, rebuilt from a clip frame as the game does
        wq, head = {}, {}
        for b, g in enumerate(GAME_BONES):
            pg = PARENT[g]
            wq[g] = (wq[pg] @ qs[b]) if pg else qs[b]
            head[g] = (head[pg] + wq[pg] @ (heads[g] - heads[pg])) if pg else off + heads["spine0"] + root
        return wq, head

    # Where each foot's last landing must move (ankle, body frame) and turn so its stance runs on into frame 0's.
    w0, h0 = fk(frames[0][0], frames[0][1])
    wM, hM = fk(end, end_off)
    land = {sd: (h0[f"leg_{sd}2"] - hM[f"leg_{sd}2"], (w0[f"leg_{sd}2"] @ wM[f"leg_{sd}2"].inverted()).normalized())
            for sd in ("l", "r")}
    print("SEAM landing moved " + " ".join(f"{sd} {m.length:.2f} m {math.degrees(min(q.angle, 2 * math.pi - q.angle)):.1f} deg"
                                         for sd, (m, q) in land.items()))

    # The stance across the seam meets halfway: the last landing moves half the gap on, the first lift-off half back
    # (each eased in over that swing), so no leg reaches far.
    first_swing = {}
    for s, sd in enumerate(("l", "r")):
        a = 0
        while a < M and frames[a][3][s]:
            a += 1
        e = a
        while e < M and not frames[e][3][s]:
            e += 1
        if 0 < a < e < M:
            first_swing[sd] = (a, e)

    def shift_of(i, sd):
        w = 0.5 * ramp(i, *window[f"leg_{sd}0"])
        if sd in first_swing:
            w -= 0.5 * (1.0 - ramp(i, *first_swing[sd]))
        return w

    def pin_leg(qs, raw_qs, off, sd, w):
        """The eased leg's knee swing onto the keyed ankle and foot, moved w of the seam's gap (two-bone IK in the plane
        of the eased knee)."""
        t, sh, ft = (f"leg_{sd}{k}" for k in range(3))
        wq, head = fk(qs, off)
        rq, rhead = fk(raw_qs, off)
        move, turn = land[sd]
        hip, ankle = head[t], rhead[ft] + move * w
        foot = (Quaternion().slerp(turn if w > 0 else turn.inverted(), abs(w)) @ rq[ft]).normalized()
        reach[0] = max(reach[0], (ankle - hip).length / (l1 + l2) if (l1 := (heads[sh] - heads[t]).length) and
                       (l2 := (heads[ft] - heads[sh]).length) else 0.0)
        l1, l2 = (heads[sh] - heads[t]).length, (heads[ft] - heads[sh]).length
        axis = ankle - hip
        d = min(max(axis.length, abs(l1 - l2) + 1e-6), l1 + l2 - 1e-6)
        u = axis.normalized()
        pole = head[sh] - hip
        pole = (pole - u * pole.dot(u)).normalized()
        a = (l1 * l1 + d * d - l2 * l2) / (2 * d)
        knee = hip + u * a + pole * math.sqrt(max(l1 * l1 - a * a, 0.0))
        tw = ((head[sh] - hip).rotation_difference(knee - hip) @ wq[t]).normalized()
        sw0 = (tw @ qs[IDX[sh]]).normalized()
        sw = ((sw0 @ (heads[ft] - heads[sh])).rotation_difference(ankle - knee) @ sw0).normalized()
        out = list(qs)
        out[IDX[t]] = (wq[PARENT[t]].inverted() @ tw).normalized()
        out[IDX[sh]] = (tw.inverted() @ sw).normalized()
        out[IDX[ft]] = (sw.inverted() @ foot).normalized()
        out[IDX[f"leg_{sd}3"]] = raw_qs[IDX[f"leg_{sd}3"]]
        return out

    before, reach = list(frames), [0.0]
    for i in range(M):
        qs, off, toes, planted, yaw, root = frames[i]
        off = off + (frames[0][1] - end_off) * ramp(i, M - SEAM, M)
        eased = [(Quaternion().slerp(gaps[b], ramp(i, *window[g])) @ qs[b]).normalized() for b, g in enumerate(GAME_BONES)]
        for s, sd in enumerate(("l", "r")):
            w = shift_of(i, sd)
            if w != 0.0 or ramp(i, *window[f"leg_{sd}0"]) > 0.0:
                eased = pin_leg(eased, qs, off, sd, w)
        frames[i] = (eased, off, toes, planted, yaw, root)
    print(f"SEAM worst turn gap {math.degrees(worst_seam):.1f} deg, pelvis gap {(frames[0][1] - end_off).length:.3f} m,"
          f" worst leg reach {reach[0]:.3f} of its length, first swings {first_swing}")

    def fk_toes(rec):  # both toe tips
        wq, head = fk(rec[0], rec[1], rec[5])
        return [head[f"leg_{sd}3"] + wq[f"leg_{sd}3"] @ (skin(AW @ last[f"leg_{sd}3"].tail_local) - heads[f"leg_{sd}3"])
                for sd in ("l", "r")]

    def knee_swing(recs):  # worst frame-to-frame turn of the shins, the loop seam included
        wqs = [fk(r[0], r[1])[0] for r in recs]
        return [max((math.degrees(wqs[i][f"leg_{sd}1"].rotation_difference(wqs[(i + 1) % M][f"leg_{sd}1"]).angle), i)
                    for i in range(M)) for sd in ("l", "r")]

    for name, recs in (("before", before), ("after", frames)):
        (lw, lf), (rw, rf) = knee_swing(recs)
        print(f"SEAM shin worst turn/frame {name}: l {lw:.1f} at f{lf} r {rw:.1f} at f{rf} deg")
        tips = [fk_toes(r) for r in recs]
        runs = []  # each stance: (side, first frame, last frame, how far the toe drifts from where it landed)
        for s in range(2):
            i = 0
            while i < M:
                if recs[i][3][s]:
                    j = i
                    while j + 1 < M and recs[j + 1][3][s]:
                        j += 1
                    runs.append((s, i, j, max((tips[k][s] - tips[i][s]).xz.length for k in range(i, j + 1))))
                    i = j + 1
                else:
                    i += 1
        print(f"SEAM stance drift {name}: " + " ".join(f"{'lr'[s]} f{a}-{b} {d:.2f}" for s, a, b, d in runs) + " m")
    print("SEAM gaps deg: " + " ".join(f"{g} {math.degrees(min(q.angle, 2 * math.pi - q.angle)):.1f}"
                                       for g, q in zip(GAME_BONES, gaps) if min(q.angle, 2 * math.pi - q.angle) > 0.02))


def mirror(rec):
    """The other turn: sides swapped and mirrored across the game's x (motion_test.py mirror_frame)."""
    qs, off, toes, planted, yaw, root = rec
    idx = {g: k for k, g in enumerate(GAME_BONES)}
    swap = lambda g: re.sub(r"_([lr])(?=\d|$)", lambda m: "_" + "rl"[m.group(1) == "r"], g)  # the side tag only
    mq = [None] * len(GAME_BONES)
    for g in GAME_BONES:
        q = qs[idx[swap(g)]]
        mq[idx[g]] = Quaternion((q.w, q.x, -q.y, -q.z))
    m = lambda v: V((-v.x, v.y, v.z))
    return mq, m(off), [m(toes[1]), m(toes[0])], [planted[1], planted[0]], -yaw, m(root)


def pack(recs):
    out = bytearray()
    cm = lambda v: [int(round(c * 100.0)) for c in v]
    for qs, off, toes, planted, yaw, root in recs:
        for q in qs:
            out += struct.pack("<4h", *(int(round(c * 32767.0)) for c in (q.x, q.y, q.z, q.w)))
        out += struct.pack("<3h", *cm(off)) + struct.pack("<6h", *(cm(toes[0]) + cm(toes[1])))
        out += struct.pack("<h", int(round(yaw * 100.0))) + struct.pack("<2h", *(int(round(c * 10.0)) for c in (root.x, root.z)))
        out += struct.pack("<BB", (1 if planted[0] else 0) | (2 if planted[1] else 0), 0)
    return out


def drop(name):
    """Takes a clip of that name out of the file (its frames, and the later clips' first frames)."""
    c = next((c for c in header["clips"] if c["name"] == name), None)
    if c is None:
        return
    fb = header["frame_bytes"]
    del body[c["first"] * fb:(c["first"] + c["frames"]) * fb]
    header["clips"].remove(c)
    for o in header["clips"]:
        if o["first"] > c["first"]:
            o["first"] -= c["frames"]


# A walk may hold several strides (the baby's 90 frames hold two): one per lift of the left foot, so the
# game's stride_m is one cycle's travel and its step clock does not run at half the keyed pace.
cycles = max(1, sum(1 for k in range(M) if frames[k - 1][3][0] and not frames[k][3][0])) if MODE == "walk" else 1
clips = [(NAME, frames)] + ([(MIRROR[NAME], [mirror(r) for r in frames])] if MODE in ("turn", "layer") else [])
for name, recs in clips:
    drop(name)
    start = sum(c["frames"] for c in header["clips"])
    entry = {"name": name, "first": start, "frames": M, "loop": MODE == "walk" or name == "idle", "cycles": cycles,
             "source": f"{Path(bpy.data.filepath).name} keyed frames {FIRST}..{FIRST + N - 1} at {KEYED_FPS} fps"}
    if name == "roar":  # the beam holds the jaw at its widest; the keyed roar arches its tail up, it never slams
        jaw = GAME_BONES.index("jaw")
        entry["jaw_peak"] = max(range(M), key=lambda k: min(recs[k][0][jaw].angle, 2 * math.pi - recs[k][0][jaw].angle))
        entry["tail_slam"] = False
    if MODE == "layer":
        entry["layer"] = True
        entry["hit"] = round(MARKS[0] / STEP, 2)
        entry["trail"] = [round(MARKS[1] / STEP, 2), round(MARKS[2] / STEP, 2)]
    header["clips"].append(entry)
    body += pack(recs)
if MODE == "walk":
    header["stride_m"] = round(travel.length / cycles, 4)
hb = json.dumps(header, separators=(",", ":")).encode()
OUT.write_bytes(b"KCLP" + struct.pack("<II", 1, len(hb)) + hb + bytes(body))
print(f"CLIP {NAME} ({MODE}) {M} frames at {header['fps']} fps from keyed {FIRST}..{FIRST + N - 1}; rest heads vs "
      f"the file {rest_gap:.3f} m; worst game-joint error {worst[0]:.3f} m ({worst[1]}); "
      f"travel {travel.length:.2f} m; end yaw {frames[-1][4]:.1f} deg")
print("PLANTED", " ".join(lows))
