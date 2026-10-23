"""Komodo TEST build (D-193, D-196, D-197): the Komodo mesh, its hand-placed skeleton and its Cascadeur
clips as the game's reptilian adult, so the director can judge the Cascadeur walk at the game camera.
Test only: Cascadeur Pro trial (D-194), nothing it makes ships; this lives on claude/komodo-test.

    blender -b --python tools/blender/komodo_import.py -- model <bridge> <out_base> [height_vox]
    blender -b --python tools/blender/komodo_import.py -- clips <bridge> <out_base> <rest.json>

<bridge> is the Cascadeur bridge folder (komodo/): mesh/komodo_10m.glb (10 m tall, Blender axes, face -Y,
+x = the creature's left, feet on z = 0), rig/komodo.blend (that mesh skinned to the skeleton of
build_komodo.py: the 27 game bones plus toe_l / toe_r) and the clip FBX exports.

model: voxelizes the GLB with tools/blender/rig_voxel.py's pipeline (texture colours, the kaiju's blocks,
D-163) on OUR skeleton instead of rig_voxel's biped fit, and writes <out_base>.kvox and .rig.json, and the
Blender skin that tools/kaiju_skin/bake.py samples (assets/kaiju/test/komodo.skin.json, .skinw, .skinf, listed
in skin_weights.json). Each voxel's bone is its strongest skin weight. The toes fold into leg_x2 for the
weights only: the game's foot bone ends at the ball.

clips: <out_base>.kclip (scenes/kaiju_clips.gd) from Cascadeur FBX exports of the same rig (CLIPS below):
resampled from 30 to 24 fps, per game bone its turn from rest (game axes), the pelvis offset, both balls,
planted bits (a foot is planted while its ball stays still in the world), the walk's stride and cycles; root
motion removed (played in place: the sim moves the body). rest.json is tools/kaiju_skin/dump_rest.gd's dump
of the rig the game builds: its lowered arm rest (BipedSwing.rest_arm_bases) is divided out of the arm turns,
so the arms show the clip's pose. The jaw has no Cascadeur control: the converter opens it for the roar.
turn_left is Cascadeur's stepping turn (stored against its turning root, TURN_*); turn_right is its mirror.
"""
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/kaiju_skin"))
import bake  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:]
TASK, BRIDGE, OUT = ARGS[0], Path(ARGS[1]), Path(ARGS[2])
SKIN_DIR = ROOT / "assets/kaiju/test"
SKIN_STEM = "komodo"
GAME_BONES = ["spine0", "spine1", "spine2", "head0", "head1", "arm_l0", "arm_l1", "arm_l2", "leg_l0",
              "leg_l1", "leg_l2", "arm_r0", "arm_r1", "arm_r2", "leg_r0", "leg_r1", "leg_r2"] + [
              f"tail{i}" for i in range(9)] + ["jaw"]
G = np.array([[-1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])  # blender (x, y, z) -> game (-x, z, y)
GM = Matrix(G.tolist())
BODY_HEIGHT_M = 10.0
# Clips: game name -> (FBX, loop-smoothed arm turns or None, loops). Frames are 30 fps; the walk's last frame
# is its first moved one stride forward, the idle's last is its first.
CLIPS = {"walk": ("rig/komodo_walk_v5c_joints.fbx", "rig/komodo_walk_v5d_arms.json", True),
         "idle": ("rig/komodo_idle_v1_joints.fbx", None, True),
         "roar": ("rig/komodo_roar_v1_joints.fbx", None, False),
         "turn_left": ("rig/komodo_turn_left_v1_joints.fbx", None, False)}
SRC_FPS, FPS = 30.0, 24
# The roar's jaw (no jaw control in Cascadeur): opens from ROAR_JAW[0] to its peak at ROAR_JAW[1] (the frame
# ClipGait holds for the beam, ROAR_PEAK_FRAME), holds, and is shut again from ROAR_JAW[2] to ROAR_JAW[3]
# (game frames, 24 fps), JAW_OPEN_DEG at the peak.
ROAR_JAW = (26.0, 47.0, 70.0, 95.0)
JAW_OPEN_DEG = 34.0
# The turn's root path (Cascadeur source frames, 30 fps), the shape of motion_test.py path("turn"): walking at
# the walk's pace (TURN_STRIDE m per TURN_CYCLE frames), the yaw eased 0 -> 90 deg to the left over TURN_YAW,
# the speed dipping TURN_DIP mid-turn. The pose is stored against this moving, turning root (pivot under the
# pelvis), its yaw in the clip (the game steers the body by it, ClipGait._steer_turn).
TURN_YAW, TURN_STRIDE, TURN_CYCLE, TURN_DIP = (37.0, 134.0), 4.0, 64.0, 0.25
# Planted: the ball moves less than this in the world per 24 fps frame (metres) ...
PLANT_SPEED = 0.025
# ... and sits within this of its lowest height in the clip (metres).
PLANT_HEIGHT = 0.12
# The tail tip's clearance over the street (metres), as in the reference clip.
TAIL_CLEAR = 0.35


def to_game(p):
    return np.asarray(p, float) @ G.T


def game_of(name):
    """The game bone a Blender bone's weights count for: the toes are part of the foot."""
    return {"toe_l": "leg_l2", "toe_r": "leg_r2"}.get(name, name)


def skeleton():
    """name -> (head, tail, parent) of the open komodo.blend armature (Blender metres; it is the FBX rest)."""
    arm = bpy.data.objects["komodo_rig"]
    mw = arm.matrix_world
    return {b.name: (np.array(mw @ b.head_local), np.array(mw @ b.tail_local), b.parent.name if b.parent else None)
            for b in arm.data.bones}


# --- model ---------------------------------------------------------------------------------------------

def rig_voxel():
    """rig_voxel.py's functions (load, to_game, surface_voxels, adopt_orphans) without its main()."""
    path = ROOT / "tools/blender/rig_voxel.py"
    src = path.read_text(encoding="utf-8")
    ns = {"__file__": str(path), "__name__": "rig_voxel"}
    exec(compile(src[:src.rindex("\nmain()")], str(path), "exec"), ns)
    return ns


def write_skin(J, scale, origin, height):
    """The Blender skin of komodo.blend in the game's axes (metres, origin = Blender's): welded positions with
    up to four weights (.skinw), the welded triangles (.skinf) and the bone list with the kvox cell map."""
    mesh = bpy.data.objects["komodo_mesh"]
    me = mesh.data
    co = np.array([mesh.matrix_world @ v.co for v in me.vertices])
    names = list(J)
    col = {g.index: names.index(g.name) for g in mesh.vertex_groups if g.name in names}
    W = np.zeros((len(co), len(names)))
    for v in me.vertices:
        for g in v.groups:
            if g.group in col:
                W[v.index, col[g.group]] = g.weight
    _, first, weld = np.unique(np.round(co / 0.001).astype(np.int64), axis=0, return_index=True, return_inverse=True)
    weld = weld.ravel()
    pos, Wp = co[first], W[first]
    order = np.argsort(-Wp, axis=1)[:, :4]
    top = np.take_along_axis(Wp, order, axis=1)
    top /= np.maximum(1e-9, top.sum(1, keepdims=True))
    idx = order.astype(np.uint8)
    idx[top <= 0] = 255
    top[top <= 0] = 0
    unweighted = int((Wp.sum(1) <= 0).sum())
    rec = np.zeros(len(pos), dtype=[("p", "<f4", 3), ("b", "u1", 4), ("w", "<f4", 4)])
    rec["p"], rec["b"], rec["w"] = to_game(pos).astype(np.float32), idx, top.astype(np.float32)
    SKIN_DIR.mkdir(parents=True, exist_ok=True)
    with open(SKIN_DIR / f"{SKIN_STEM}.skinw", "wb") as f:
        f.write(b"KSKW" + np.array([1, len(pos)], "<u4").tobytes() + np.array([len(names)], "<u2").tobytes())
        f.write(rec.tobytes())
    me.calc_loop_triangles()
    tris = np.array([[weld[i] for i in t.vertices] for t in me.loop_triangles], dtype=np.int64)
    tris = tris[(tris[:, 0] != tris[:, 1]) & (tris[:, 1] != tris[:, 2]) & (tris[:, 0] != tris[:, 2])]
    with open(SKIN_DIR / f"{SKIN_STEM}.skinf", "wb") as f:
        f.write(b"KSKF" + struct.pack("<II", 1, len(tris)) + tris.astype("<u4").tobytes())

    def cell_to_skin(gc):  # rig_voxel's cell (game) -> its centre in skin space
        k = np.array([-(gc[0] + 1), gc[2], gc[1]], float)
        return to_game((k + 0.5) / scale + origin)
    o0 = cell_to_skin((0, 0, 0))
    M = np.eye(4)
    for i in range(3):
        e = [0, 0, 0]
        e[i] = 1
        M[:3, i] = cell_to_skin(e) - o0
    M[:3, 3] = o0
    bones = [{"name": n, "game": game_of(n), "parent": p, "head": to_game(h).round(4).tolist(),
              "tail": to_game(t).round(4).tolist(), "physics": n.startswith("tail"), "jaw": n == "jaw"}
             for n, (h, t, p) in J.items()]
    doc = {"version": 1, "units": "m", "axes": "game: Y up, -Z forward, x = -blender x; the Komodo's own "
           "metres (10 m tall), origin = the GLB's", "height_m": BODY_HEIGHT_M, "source": SKIN_STEM,
           "bones": bones, "vertex_count": int(len(pos)), "weights_file": f"{SKIN_STEM}.skinw",
           "kvox_height": height, "kvox_cell_to_skin": M.round(6).tolist(),
           "kvox_note": "p_skin = M @ (gx, gy, gz, 1): centre of a cell of <out_base>.kvox. TEST ONLY (D-194)."}
    meta = SKIN_DIR / f"{SKIN_STEM}.skin.json"
    meta.write_text(json.dumps(doc, indent=1), encoding="utf-8", newline="\n")
    print(f"skin: {len(co)} -> {len(pos)} welded positions, {len(tris)} triangles, {unweighted} unweighted")
    return meta


def model(height):
    rv = rig_voxel()
    glb = BRIDGE / "mesh/komodo_10m.glb"
    v, _n, tris, texture = rv["load"](str(glb))
    lo, hi = v.min(0), v.max(0)
    scale = (height - 1) / (hi[2] - lo[2])
    origin = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    grey = np.full((len(v), 3), 0.4)
    cells = rv["surface_voxels"](v, tris, grey, scale, origin, texture)
    print("colours from", "texture" if texture is not None else "NOTHING (grey)", f"; {len(cells)} voxels")
    keys = np.array(list(cells.keys()))
    values = list(cells.values())
    bpy.ops.wm.open_mainfile(filepath=str(BRIDGE / "rig/komodo.blend"))
    J = skeleton()
    meta = write_skin(J, scale, origin, height)
    gk = rv["to_game"](keys.astype(float))
    gk[:, 0] -= 1  # integer cells after the x flip (rig_voxel)
    gk = gk.astype(int)
    w, gap = bake.sample_skin(meta, gk, GAME_BONES)
    owner = np.argmax(w, axis=1)
    owner = rv["adopt_orphans"](gk, owner)
    rig_bones = [{"name": g, "parent": J[g][2], "head": J[g][0], "tail": J[g][1]} for g in GAME_BONES]
    # No clean_blemishes: it is the croc titan's fix (pink spots on a green hide); on the Komodo's warm hide it
    # recoloured 22k torso voxels.
    with open(OUT.with_suffix(".kvox"), "wb") as f:
        f.write(b"KVOX" + struct.pack("<IIH", 2, 1, height) + struct.pack("<I", len(values)))
        for g, (r, gr, b, cnt), bone in zip(gk, values, owner):
            rgb = [int(max(0, min(255, round(x / cnt * 255)))) for x in (r, gr, b)]
            f.write(struct.pack("<hhhBBBB", g[0], g[1], g[2], *rgb, int(bone)))
    rig = {"height": height, "type": "biped", "bones": []}
    for b in rig_bones:
        head = rv["to_game"](((b["head"] - origin) * scale)[None])[0]
        tail = rv["to_game"](((b["tail"] - origin) * scale)[None])[0]
        entry = {"name": b["name"], "parent": b["parent"], "head": head.round(2).tolist(),
                 "tail": tail.round(2).tolist(), "physics": b["name"].startswith("tail")}
        if b["name"] == "jaw":
            entry["close"] = 0.0
        rig["bones"].append(entry)
    OUT.with_suffix(".rig.json").write_text(json.dumps(rig, indent=1), encoding="utf-8", newline="\n")
    listing = OUT.parent / "skin_weights.json"
    table = json.loads(listing.read_text(encoding="utf-8"))
    table[OUT.name] = f"test/{SKIN_STEM}.skin.json"
    listing.write_text(json.dumps(table, indent=2) + "\n", encoding="utf-8", newline="\n")
    counts = np.bincount(owner, minlength=len(GAME_BONES))
    print(f"komodo {OUT.name}: {len(values)} voxels at height {height}; gap to skin median {np.median(gap):.3f} m "
          f"p95 {np.percentile(gap, 95):.3f} m; per bone " + ", ".join(f"{g} {c}" for g, c in zip(GAME_BONES, counts)))


# --- clips ---------------------------------------------------------------------------------------------

def arm_relax(rest_path):
    """game bone -> the local rest turn the game gives it beyond the skeleton's (the lowered arms)."""
    entry = json.loads(Path(rest_path).read_text(encoding="utf-8"))[OUT.name]
    basis = {b["name"]: np.array(b["xform"][:9]).reshape(3, 3).T for b in entry["bones"]}  # columns x y z
    out = {}
    for side in "lr":
        above = np.eye(3)
        for i in range(3):
            n = f"arm_{side}{i}"
            local = above.T @ basis[n]
            out[n] = Matrix(local.tolist()).to_quaternion()
            above = basis[n]
    for n, b in basis.items():
        if not n.startswith("arm") and np.abs(b - np.eye(3)).max() > 1e-4:
            print(f"WARNING: the game turns {n} at rest too; its clip turns are not compensated")
    return out


def load_clip(fbx, arms):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(BRIDGE / fbx), automatic_bone_orientation=False)
    arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
    f0, f1 = (int(x) for x in arm.animation_data.action.frame_range)
    if arms:  # loop-smoothed hand turns over the FBX's arms, baked as keys
        rot = json.loads((BRIDGE / arms).read_text(encoding="utf-8"))
        for f in range(f0, f1 + 1):
            for name, qs in rot["rot"].items():
                pb = arm.pose.bones[name]
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = qs[f - rot["f0"]]
                pb.keyframe_insert("rotation_quaternion", frame=f)
    return arm, f0, f1


def lift_tail(arm):
    """The tail rests straight (ClipGait poses the tail from the clip, adding only its turn swing), curled up
    just enough that its tip stays TAIL_CLEAR above the street as the pelvis sinks (the reference clip's
    render_walk1.py lift_tail); returns the curl (deg per joint, signed)."""
    tails = [pb for pb in arm.pose.bones if pb.name.startswith("tail")]
    tip = arm.pose.bones["tail8"]

    def tip_z(deg):
        for pb in tails:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(deg))
        bpy.context.view_layer.update()
        return (arm.matrix_world @ tip.tail).z
    if tip_z(0.0) >= TAIL_CLEAR:
        return 0.0
    for deg in [s * d * 0.5 for d in range(1, 41) for s in (1, -1)]:
        if tip_z(deg) >= TAIL_CLEAR:
            return deg
    tip_z(0.0)
    return 0.0


def sample(arm, t):
    """Every bone's world turn from rest and head (Blender) at fractional frame t, and both balls."""
    bpy.context.scene.frame_set(int(math.floor(t)), subframe=t - math.floor(t))
    bpy.context.view_layer.update()
    sample.curl = lift_tail(arm)
    turns, heads = {}, {}
    for pb in arm.pose.bones:
        rest = pb.bone.matrix_local.to_3x3().normalized()
        turns[pb.name] = (pb.matrix.to_3x3().normalized() @ rest.inverted()).to_quaternion()
        heads[pb.name] = Vector(pb.head)
    balls = [Vector(arm.pose.bones[f"toe_{s}"].head) for s in "lr"]  # game left (-x) is our _l (blender +x)
    return turns, heads, balls


def game_locals(turns, parents):
    """Local turns of the game bones in game axes (every game bone rests with an identity basis)."""
    world = {g: (GM @ turns[g].to_matrix() @ GM.transposed()).to_quaternion() for g in GAME_BONES}
    return [((world[parents[g]].inverted() @ world[g]) if parents[g] else world[g]).normalized() for g in GAME_BONES]


def fk_error(J, qs, heads):
    """Worst distance (m) of a game bone's head, rebuilt from the local turns as the game does, from the posed
    Blender head (pelvis offset applied): the clip carries the pose."""
    world, head, worst = {}, {}, (0.0, "")
    off = GM @ (heads["spine0"] - Vector(J["spine0"][0]))
    for g, q in zip(GAME_BONES, qs):
        p = J[g][2]
        rest_h = GM @ Vector(J[g][0])
        if p is None:
            world[g], head[g] = q, rest_h + off
        else:
            world[g] = world[p] @ q
            head[g] = head[p] + world[p] @ (rest_h - GM @ Vector(J[p][0]))
        worst = max(worst, ((head[g] - GM @ heads[g]).length, g))
    return worst


def turn_path(span):
    """The turn's root: (travel from the start, yaw in degrees) at a source frame (fractional), integrated."""
    eased = lambda f: (lambda u: u * u * (3 - 2 * u))(min(1.0, max(0.0, (f - TURN_YAW[0]) / (TURN_YAW[1] - TURN_YAW[0]))))
    pos, track = Vector((0, 0, 0)), []
    for f in range(span + 2):
        k = eased(f)
        track.append(pos.copy())
        speed = TURN_STRIDE / TURN_CYCLE * (1 - TURN_DIP * math.sin(math.pi * k))
        pos += Quaternion((0, 0, 1), math.radians(90.0 * k)) @ Vector((0, -speed, 0))
    def at(f):
        f0 = int(math.floor(f))
        return track[f0].lerp(track[f0 + 1], f - f0), 90.0 * eased(f)
    return at


def to_root(p, root, yaw, pivot):
    """A Blender point in the root's frame: the root at `root` turned by `yaw` about the pelvis's rest spot."""
    return Quaternion((0, 0, 1), -math.radians(yaw)) @ (p - root) + pivot


def record(name, J, relax):
    fbx, arms, loop = CLIPS[name]
    arm, f0, f1 = load_clip(fbx, arms)
    span = f1 - f0
    n = int(round(span * FPS / SRC_FPS))
    step = span / n
    parents = {g: J[g][2] for g in GAME_BONES}
    _, h0, _ = sample(arm, f0)
    _, h1, _ = sample(arm, f1)
    start = h0["spine0"].copy()
    start.z = 0.0
    pivot = Vector(J["spine0"][0])
    pivot.z = 0.0
    trip = (h1["spine0"] - h0["spine0"]) if loop else Vector((0, 0, 0))
    trip.z = 0.0
    path = turn_path(span) if name.startswith("turn") else (lambda f: (trip * (f / span), 0.0))
    frames, worst, balls_w, curls = [], (0.0, ""), [], []
    for i in range(n):
        t = f0 + i * step
        turns, heads, balls = sample(arm, t)
        travel, yaw = path(i * step)
        root = start + travel
        spin = Quaternion((0, 0, 1), -math.radians(yaw))
        turns = {b: spin @ q for b, q in turns.items()}
        heads = {b: to_root(h, root, yaw, pivot) for b, h in heads.items()}
        qs = game_locals(turns, parents)
        worst = max(worst, fk_error(J, qs, heads) + (f"f{i}",))
        k = GAME_BONES.index("jaw")
        if name == "roar":
            ease = lambda a, b, x: (lambda u: u * u * (3 - 2 * u))(min(1.0, max(0.0, (x - a) / (b - a))))
            opened = ease(ROAR_JAW[0], ROAR_JAW[1], i) * (1 - ease(ROAR_JAW[2], ROAR_JAW[3], i))
            qs[k] = qs[k] @ Quaternion((1, 0, 0), -math.radians(JAW_OPEN_DEG * opened))
        else:
            qs[k] = Quaternion()  # shut at rest and walking
        curls.append(sample.curl)
        for t_i, g in enumerate(GAME_BONES):
            if g in relax:
                qs[t_i] = relax[g].inverted() @ qs[t_i]
        off = GM @ (heads["spine0"] - Vector(J["spine0"][0]))
        feet = [GM @ to_root(b, root, yaw, pivot) for b in balls]
        balls_w.append([np.array(b) for b in balls])
        frames.append([qs, off, feet, [True, True], yaw, GM @ travel])
    # Planted: the ball still in the world (wrapping a loop) and down near its lowest.
    bw = np.array(balls_w)  # frames x 2 x 3, world
    if loop:
        last = bw[0] + np.array(trip)
        nxt = np.concatenate([bw[1:], last[None]])
        prv = np.concatenate([(bw[-1] - np.array(trip))[None], bw[:-1]])
    else:
        nxt = np.concatenate([bw[1:], bw[-1:]])
        prv = np.concatenate([bw[:1], bw[:-1]])
    speed = np.linalg.norm((nxt - prv)[..., :2], axis=-1) / 2
    low = bw[..., 2].min(0)
    planted = (speed < PLANT_SPEED) & (bw[..., 2] < low + PLANT_HEIGHT)
    for fr, p in zip(frames, planted):
        fr[3] = [bool(p[0]), bool(p[1])]
    pattern = ["".join("#" if p else "." for p in planted[:, s]) for s in range(2)]
    plants = [int(np.sum(planted[:, s] & ~np.roll(planted[:, s], 1))) for s in range(2)]
    print(f"clip {name}: {span} frames at 30 fps -> {n} at 24; travel {trip.length:.3f} m; worst rebuilt head "
          f"{worst[0]:.4f} m ({worst[1]} {worst[2]}); ball speed max {speed.max():.3f} m/frame; tail curl {min(curls):.1f}..{max(curls):.1f} deg; plants L {plants[0]} R {plants[1]}\n"
          f"  L {pattern[0]}\n  R {pattern[1]}")
    return frames, trip.length, max(1, min(plants)) if loop else 1


def mirror(rec):
    """turn_right from turn_left: swap the sides and mirror across the game's x (motion_test.mirror_frame)."""
    qs, off, feet, contact, yaw, travel = rec
    swap = lambda g: g.replace("_l", "_R").replace("_r", "_l").replace("_R", "_r")
    mq = [Quaternion((qs[GAME_BONES.index(swap(g))].w, qs[GAME_BONES.index(swap(g))].x,
                      -qs[GAME_BONES.index(swap(g))].y, -qs[GAME_BONES.index(swap(g))].z)) for g in GAME_BONES]
    m = lambda v: Vector((-v.x, v.y, v.z))
    return [mq, m(off), [m(feet[1]), m(feet[0])], [contact[1], contact[0]], -yaw, m(travel)]


def clips(rest_path):
    bpy.ops.wm.open_mainfile(filepath=str(BRIDGE / "rig/komodo.blend"))
    J = skeleton()
    relax = arm_relax(rest_path)
    recorded, stride, cycles = {}, 1.0, 1
    for name in CLIPS:
        frames, trip, c = record(name, J, relax)
        recorded[name] = frames
        if name == "walk":
            stride, cycles = trip / c, c
    recorded["turn_right"] = [mirror(r) for r in recorded["turn_left"]]
    body, table, start = bytearray(), [], 0
    cm = lambda v: [int(round(c * 100.0)) for c in v]
    for name in ("idle", "walk", "turn_left", "turn_right", "roar"):
        frames = recorded[name]
        for qs, off, feet, contact, yaw, travel in frames:
            for q in qs:
                body += struct.pack("<4h", *(int(round(c * 32767.0)) for c in (q.x, q.y, q.z, q.w)))
            body += struct.pack("<3h", *cm(off))
            body += struct.pack("<6h", *(cm(feet[0]) + cm(feet[1])))
            body += struct.pack("<h", int(round(yaw * 100)))
            body += struct.pack("<2h", *(int(round(c * 10.0)) for c in (travel.x, travel.z)))
            body += struct.pack("<BB", (1 if contact[0] else 0) | (2 if contact[1] else 0), 0)
        table.append({"name": name, "first": start, "frames": len(frames), "loop": name in ("idle", "walk"),
                      "cycles": cycles if name == "walk" else 1})
        start += len(frames)
    gathers = {g: [g] + ([f"toe_{g[4]}"] if g in ("leg_l2", "leg_r2") else []) for g in GAME_BONES}
    heads = {g: [round(float(x), 4) for x in to_game(J[g][0])] for g in GAME_BONES}
    header = json.dumps({"version": 1, "fps": FPS, "frame_bytes": len(GAME_BONES) * 8 + 26, "bones": GAME_BONES,
                         "gathers": gathers, "rest_heads_m": heads, "stride_m": round(stride, 4),
                         "body_height_m": BODY_HEIGHT_M, "clips": table,
                         "source": "Cascadeur komodo (TEST ONLY, D-194)"},
                        separators=(",", ":")).encode()
    out = OUT.with_suffix(".kclip")
    out.write_bytes(b"KCLP" + struct.pack("<II", 1, len(header)) + header + bytes(body))
    print(f"clips {out.name}: {[(c['name'], c['frames']) for c in table]}, stride {stride:.3f} m x {cycles} "
          f"cycles, {out.stat().st_size} bytes")


if TASK == "model":
    model(int(ARGS[3]) if len(ARGS) > 3 else 320)
elif TASK == "clips":
    clips(ARGS[3])
else:
    raise SystemExit(f"unknown task {TASK}")
