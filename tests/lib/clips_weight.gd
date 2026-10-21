extends RefCounted
## The croc titan's walk carries weight (ClipWeight; director 2026-10-21 #4: "kaiju needs more
## motion in the shoulders and head while it walks"; research 11 R 11.2-11.4, 14 R 14.1-14.3).
## Measurements for tests/run_walk_tests.gd: the same fixed 60 Hz walk or standing turn with
## ClipWeight on and off (the bare clips).
## Seeded by design: no randomness (the gaits seed their own twitches).

const DT := 1.0 / 60.0
const SCALES := {"baby": 0.5, "adolescent": 0.92, "adult": 1.35}  # the game's body scales
const SPEED := 5.5  # the reptilian's base speed (units/s)


## What a straight walk showed (rad, per frame; cycles/s; strides world units; drift hips).
class Walked:
	var chest_roll: Array[float] = []
	var chest_twist: Array[float] = []
	var pelvis_roll: Array[float] = []
	var pelvis_twist: Array[float] = []
	var head_pitch: Array[float] = []
	var strength: Array[float] = []
	var catches := 0
	var cycles_s := 0.0
	var stride := 0.0
	var base_stride := 0.0
	var drift := 0.0


static func model(root: Node, stage: String) -> KaijuModel:
	var def: Dictionary = Content.species_def("reptilian")
	var colors: Dictionary = def["colors"]
	var kaiju := KaijuModel.new("reptilian", colors, stage)
	kaiju.scale = Vector3.ONE * Num.f(SCALES[stage])
	root.add_child(kaiju)
	return kaiju


static func gait(kaiju: KaijuModel) -> ClipGait:
	return kaiju._rig.gait


## Walks north at speed for frames, calling each(frame) after every animate.
static func walk(kaiju: KaijuModel, frames: int, speed: float, each: Callable) -> void:
	for f: int in frames:
		kaiju.position += Vector3(0, 0, -speed * DT)
		kaiju.animate(DT, 1.0)
		each.call(f)


## A bone's turn from ref as a world rotation vector (x right, y up, z back), radians.
static func turn_of(rig: KaijuRig, bone_name: String, ref: Basis) -> Vector3:
	var now := rig.bone(bone_name).global_transform.basis.orthonormalized()
	var q := (now * ref.inverse()).get_rotation_quaternion()
	return q.get_axis() * q.get_angle() if q.get_angle() > 0.000001 else Vector3.ZERO


static func spread(xs: Array[float]) -> float:
	if xs.is_empty():
		return 0.0
	var lo := INF
	var hi := -INF
	for x: float in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return hi - lo


static func correlation(a: Array[float], b: Array[float]) -> float:
	var n := mini(a.size(), b.size())
	var ma := 0.0
	var mb := 0.0
	for i: int in n:
		ma += a[i] / n
		mb += b[i] / n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i: int in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	return sab / sqrt(maxf(saa * sbb, 1e-12))


## A straight walk at speed: 2 s into the walk, then 6 s measured. off: the bare clips.
static func measure(root: Node, stage: String, off: bool, speed: float = SPEED) -> Walked:
	ClipWeight.off = off
	var kaiju := model(root, stage)
	var g := gait(kaiju)
	var rig := kaiju._rig
	var got := Walked.new()
	rig.foot_planted.connect(
		func(side: String, k: float, _at: Vector3) -> void:
			if side != "tail":
				got.strength.append(k)
	)
	walk(kaiju, 120, speed, func(_f: int) -> void: pass)
	var ref_pelvis := rig.bone("spine0").global_transform.basis.orthonormalized()
	var ref_chest := rig.bone("spine2").global_transform.basis.orthonormalized()
	var ref_head := rig.bone("head1").global_transform.basis.orthonormalized()
	var cycles0 := g.walk_cycles
	got.strength.clear()
	var was: Array[bool] = [false, false]
	var each := func(_f: int) -> void:
		var pelvis := turn_of(rig, "spine0", ref_pelvis)
		var chest := turn_of(rig, "spine2", ref_chest)
		got.pelvis_roll.append(-pelvis.z)
		got.pelvis_twist.append(pelvis.y)
		got.chest_roll.append(-chest.z)
		got.chest_twist.append(chest.y)
		got.head_pitch.append(turn_of(rig, "head1", ref_head).x)
		for i: int in 2:
			var c: bool = g._catch[i] > 0.0
			if c and not was[i]:
				got.catches += 1
			was[i] = c
	walk(kaiju, 360, speed, each)
	got.cycles_s = (g.walk_cycles - cycles0) / (360 * DT)
	got.stride = g.stride()
	got.base_stride = g.base_stride()
	got.drift = kaiju.foot_drift() / kaiju.hip_height()
	kaiju.free()
	ClipWeight.off = false
	return got


## (x) The pelvis's deepest footfall drop (hip heights) and (y) how long (s) the cross-fade from
## standing into the walk takes, at a stage.
static func footfall_and_start(root: Node, stage: String, off: bool = false) -> Vector2:
	ClipWeight.off = off
	var kaiju := model(root, stage)
	var g := gait(kaiju)
	for f: int in 30:
		kaiju.animate(DT, 0.0)
	var got: Array[float] = [-1.0, 0.0]  # a lambda can edit an array, not a local
	walk(
		kaiju,
		240,
		SPEED,
		func(f: int) -> void:
			if got[0] < 0.0 and g.state == "walk" and g._blend >= 1.0:
				got[0] = (f + 1) * DT
			got[1] = maxf(got[1], g.weight.drop)
	)
	var drop := got[1] / g.hip_height
	kaiju.free()
	ClipWeight.off = false
	return Vector2(drop, got[0])


## Every bone's world transform after a walk of frames (the determinism check).
static func pose_after(root: Node, frames: int) -> Array[Transform3D]:
	var kaiju := model(root, "adult")
	walk(kaiju, frames, SPEED, func(_f: int) -> void: pass)
	var out: Array[Transform3D] = []
	for b: String in kaiju._rig.bone_names():
		out.append(kaiju._rig.bone(b).global_transform)
	kaiju.free()
	return out
