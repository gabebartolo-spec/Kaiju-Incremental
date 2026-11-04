"""Copies a T-rex clip (a Sketchfab GLB, CC BY 4.0, docs/LICENSING_REGISTER.md) onto the croc adult3 rig r11 (D-461).
    blender -b croc_adult3_rig_r11.blend --python tools/blender/trex_retarget.py -- <model.glb> <action> <out.blend>
            <src start s> <src end s> <speed> <ground 0|1>
Samples the source action from <src start> to <src end> seconds (source time; a time before 0 holds the first pose) at
30 keyed frames per clip second (what croc_adult3_clips.py reads), <speed> source seconds per clip second, and keys
croc_rig with it; <out.blend> is then baked with croc_adult3_clips.py. Nothing of the source mesh or textures is kept.
No pose is invented: every rig bone takes the world turn (against rest) the matching source bone makes, turned to the
rig's facing (the rexes face -Y, the rig +X); a chain of fewer or more bones takes the turns blended along its length.
The pelvis takes the source hip's move, scaled by the hip heights. <ground> 1 lifts the whole body so the lowest toe
stands where it does at rest on the first frame (the proportions differ; the feet must not sink or float).
"""
import bpy, sys, math
from mathutils import Matrix, Quaternion, Vector as V

a = sys.argv[sys.argv.index("--") + 1:]
GLB, ACTION, OUT = a[0], a[1], a[2]
T0, T1, SPEED, GROUND = float(a[3]), float(a[4]), float(a[5]), int(a[6])
KEYED_FPS = 30
rig = bpy.data.objects["croc_rig"]
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=GLB)
src = next(o for o in bpy.data.objects if o not in before and o.type == "ARMATURE")
src.animation_data.action = bpy.data.actions[ACTION]
scene = bpy.context.scene
SRC_FPS = scene.render.fps

# Rig bone <- source bone, or a chain of source bones blended along the length of a chain of rig bones.
SINGLE = {
    "rex": {  # "Tyrannosaurus rex (reuploaded and retextured)", Sketchfab 5454151e22db4ae9966db7a5a98ffb09
        "pelvis": "T_Rex_ROOTSHJnt_01", "head": "T_Rex_Head_TopSHJnt_011", "jaw": "T_Rex_Head_JawSHJnt_09",
        "clavicle_l": "T_Rex_l_Arm_ClavicleSHJnt_018", "upperarm_l": "T_Rex_l_Arm_ShoulderSHJnt_019",
        "forearm_l": "T_Rex_l_Arm_ElbowSHJnt_020", "hand_l": "T_Rex_l_Arm_WristSHJnt_021",
        "clavicle_r": "T_Rex_r_Arm_ClavicleSHJnt_024", "upperarm_r": "T_Rex_r_Arm_ShoulderSHJnt_025",
        "forearm_r": "T_Rex_r_Arm_ElbowSHJnt_026", "hand_r": "T_Rex_r_Arm_WristSHJnt_027",
        "thigh_l": "T_Rex_l_Leg_HipSHJnt_030", "shin_l": "T_Rex_l_Leg_Knee1SHJnt_031",
        "foot_l": "T_Rex_l_Leg_Knee2SHJnt_032", "toe_l": "T_Rex_l_Leg_BallSHJnt_034",
        "thigh_r": "T_Rex_r_Leg_HipSHJnt_045", "shin_r": "T_Rex_r_Leg_Knee1SHJnt_046",
        "foot_r": "T_Rex_r_Leg_Knee2SHJnt_047", "toe_r": "T_Rex_r_Leg_BallSHJnt_049",
    },
    "rampage": {  # "Rampaging Tyrannosaurus Rex", Sketchfab 4abe5f31267a4fde8cd7eb1f9c41d938
        "pelvis": "bn_Spine.4_4", "head": "bn_Head.10_10", "jaw": "bn_Jaw.11_11",
        "clavicle_l": "bn_LeftShoulder.27_27", "upperarm_l": "bn_LeftArm.28_28", "forearm_l": "bn_LeftForeArm.29_29",
        "hand_l": "bn_LeftHand.30_30",
        "clavicle_r": "bn_RightShoulder.35_35", "upperarm_r": "bn_RightArm.36_36", "forearm_r": "bn_RightForeArm.37_37",
        "hand_r": "bn_RightHand.38_38",
        "thigh_l": "bn_LeftUpLeg.45_45", "shin_l": "bn_LeftLeg.46_46", "foot_l": "bn_LeftFoot.47_47",
        "toe_l": "bn_LeftBall.48_48",
        "thigh_r": "bn_RightUpLeg.56_56", "shin_r": "bn_RightLeg.57_57", "foot_r": "bn_RightFoot.58_58",
        "toe_r": "bn_RightBall.59_59",
    },
}
TAIL_RIG = [f"tail{i:02d}" for i in range(12)]
CHAINS = {
    "rex": {
        "torso": (["T_Rex_Spine_01SHJnt_02", "T_Rex_Spine_02SHJnt_03", "T_Rex_Spine_03SHJnt_04",
                   "T_Rex_Spine_04SHJnt_05", "T_Rex_Spine_TopSHJnt_06"], ["lumbar0", "lumbar1", "chest"]),
        "neck": (["T_Rex_Neck_01SHJnt_07", "T_Rex_Neck_TopSHJnt_08"], ["neck0", "neck1", "neck2"]),
        "tail": ([f"T_Rex_Tail_01_0{i}SHJnt_0{58 + i}" for i in range(1, 10)], TAIL_RIG),
    },
    "rampage": {
        "torso": (["bn_Spine1.5_5", "bn_Spine2.6_6"], ["lumbar0", "lumbar1", "chest"]),
        "neck": (["bn_Neck.7_7", "bn_Neck1.8_8", "bn_Neck2.9_9"], ["neck0", "neck1", "neck2"]),
        "tail": ([f"bn_Tail0{i}.{66 + i}_{66 + i}" for i in range(1, 9)], TAIL_RIG),
    },
}
kind = "rex" if "T_Rex_ROOTSHJnt_01" in src.data.bones else "rampage"
single, chains = SINGLE[kind], CHAINS[kind]
for n in list(single.values()) + [n for c in chains.values() for n in c[0]]:
    assert n in src.data.bones, f"{n} is not a bone of {GLB}"

# The rexes face -Y, the rig +X: a turn of +90 deg about Z maps one frame to the other (no mirror: left stays left).
C = Matrix.Rotation(math.pi / 2, 3, "Z")
Cq = C.to_quaternion()
rest_q = lambda ob, n: ob.data.bones[n].matrix_local.to_3x3().normalized().to_quaternion()


def fractions(ob, names):
    """Each bone's midpoint as the share of the chain's length (head of the first to tail of the last)."""
    bones = [ob.data.bones[n] for n in names]
    start = bones[0].head_local
    total = (bones[-1].tail_local - start).length
    return [((b.head_local + b.tail_local) / 2 - start).length / total for b in bones]


def blend(ts, qs, t):
    if t <= ts[0]:
        return qs[0].copy()
    for i in range(len(ts) - 1):
        if t <= ts[i + 1]:
            return qs[i].slerp(qs[i + 1], (t - ts[i]) / (ts[i + 1] - ts[i]))
    return qs[-1].copy()


plan = {k: ("one", v) for k, v in single.items()}
for src_names, tgt_names in chains.values():
    sf = fractions(src, src_names)
    for t, n in zip(fractions(rig, tgt_names), tgt_names):
        plan[n] = ("chain", (src_names, sf, t))

order = []  # rig bones, parents first
def walk(b):
    order.append(b.name)
    for c in b.children:
        walk(c)
for b in rig.data.bones:
    if b.parent is None:
        walk(b)

HIP = single["pelvis"]
RATIO = (rig.data.bones["pelvis"].head_local.z + 0.184) / src.data.bones[HIP].head_local.z  # pelvis over the ground
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.action = bpy.data.actions.new("trex_" + ACTION)


def delta_of(n):
    """The source bone's world turn against its rest (armature space)."""
    return src.pose.bones[n].matrix.to_3x3().normalized().to_quaternion() @ rest_q(src, n).inverted()


def hip_move(lift):
    move = src.pose.bones[HIP].head - src.data.bones[HIP].head_local
    return rest_q(rig, "pelvis").inverted() @ ((C @ move) * RATIO + V((0.0, 0.0, lift)))


n_frames = int(math.floor((T1 - T0) / SPEED * KEYED_FPS + 1e-6)) + 1
scene.frame_start, scene.frame_end = 1, n_frames
toe_rest = {s: rig.data.bones[f"toe_{s}"].tail_local.z for s in "lr"}
lift = 0.0
for k in range(n_frames):
    fr = max(T0 + k / KEYED_FPS * SPEED, 0.0) * SRC_FPS
    scene.frame_set(int(math.floor(fr)), subframe=fr - math.floor(fr))
    delta = {}
    for n in order:
        how, info = plan.get(n, (None, None))
        if how == "one":
            d = delta_of(info)
        elif how == "chain":
            d = blend(info[1], [delta_of(s) for s in info[0]], info[2])
        else:  # helpers, eyelids and the rest follow their parent
            par = rig.data.bones[n].parent
            d = delta[par.name] if par is not None else Quaternion()
        delta[n] = Cq @ d @ Cq.inverted()
    for n in order:
        b = rig.data.bones[n]
        r_c = rest_q(rig, n)
        dp = delta[b.parent.name] if b.parent is not None else Quaternion()
        rig.pose.bones[n].rotation_quaternion = r_c.inverted() @ (dp.inverted() @ delta[n]) @ r_c
    rig.pose.bones["pelvis"].location = hip_move(lift)
    if GROUND and k == 0:
        bpy.context.view_layer.update()
        lift = -min(rig.pose.bones[f"toe_{s}"].tail.z - toe_rest[s] for s in "lr")
        rig.pose.bones["pelvis"].location = hip_move(lift)
        print(f"GROUND lift {lift:.4f} m on the first frame")
    for n in order:
        rig.pose.bones[n].keyframe_insert("rotation_quaternion", frame=k + 1)
    rig.pose.bones["pelvis"].keyframe_insert("location", frame=k + 1)
for o in list(bpy.data.objects):
    if o not in before:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print(f"RETARGET {ACTION}: {n_frames} keyed frames, hip ratio {RATIO:.6f}, saved {OUT}")
