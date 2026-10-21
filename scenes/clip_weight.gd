class_name ClipWeight
extends RefCounted
## The weight on top of the croc titan's baked walk (ClipGait; director 2026-10-21 #4: "kaiju
## needs more motion in the shoulders and head while it walks"; research 11 R 11.2-11.4 and 14
## R 14.3). Presentation only; numbers in data/tuning.json "walk", [baby, adult] pairs lerped by
## body scale.
## - Stride from speed: past "playback_max" x the clip's authored cadence, the stride stretches
##   (up to "warp_max" x the baked one) instead of the legs spinning faster.
## - Shoulders counter the hips: the chest twists and rolls opposite the pelvis's clip sway.
## - The head steadies against the shoulders and bobs on a lagging spring, settling after each step.
## - Every footfall lands: the pelvis drops and recovers, the head and jaw take a kick, harder
##   for an adult; a start eases in, a stop is short.

## A kick's deepest swing is about 1 / KICK_PEAK of (its speed / omega) on a spring damped ~0.5.
const KICK_PEAK := 1.8

## Debug: true walks on the bare clips (tests, before/after captures).
static var off := false

## The stride's stretch now (1 = as baked); the pelvis drop (rig units, down +).
var warp := 1.0
var drop := 0.0
## The head's bob (rad, pitch down +) and the chest's added twist and roll (rad).
var nod := 0.0
var twist := 0.0
var roll := 0.0
var cfg: Dictionary
var _drop_v := 0.0
var _nod_v := 0.0
var _jaw := 0.0
var _jaw_v := 0.0
var _mean := Quaternion.IDENTITY  # the pelvis's mean turn over the walk
var _bob := Vector2.ZERO  # the pelvis offset's height: mean, half range (m)
var _feet_z := 0.0  # the toes' mean fore-aft spot over the walk (m)
var _authored := 1.0  # seconds per walk cycle as baked
var _warp_max := 1.0  # this clip set's longest stretch before its legs overreach
var _pelvis := 0  # the pelvis bone's track
var _walk := 0.0  # the walk's share of the pose, and the body scale, as shape() saw them
var _s := 1.0


func _init(clips: KaijuClips) -> void:
	cfg = Content.section("walk")
	var reach: Dictionary = cfg["warp_max"]
	_warp_max = Num.f(reach.get(clips.source, 1.0))
	var n := clips.frames_of("walk")
	var lo := INF
	var hi := -INF
	_pelvis = maxi(0, clips.bones.find("spine0"))
	var i0 := _pelvis
	var sum := Quaternion(0, 0, 0, 0)
	var first := clips.pose_at("walk", 0).turns[i0]
	for t: int in n:
		var p := clips.pose_at("walk", t)
		sum += p.turns[i0] if p.turns[i0].dot(first) >= 0.0 else -p.turns[i0]
		lo = minf(lo, p.offset.y)
		hi = maxf(hi, p.offset.y)
		_feet_z += (p.feet[0].z + p.feet[1].z) * 0.5
	_mean = sum.normalized() if sum.length() > 0.0 else Quaternion.IDENTITY
	_feet_z /= maxf(1.0, n)
	_bob = Vector2((lo + hi) * 0.5, maxf(0.001, (hi - lo) * 0.5))
	_authored = float(n) / clips.fps / maxf(1.0, clips.cycles_of("walk"))


## 0 baby .. 1 adult, by body scale (BipedGait's young-to-adult range).
static func grown(s: float) -> float:
	return clampf(
		(s - BipedGait.BABY_SCALE) / (BipedGait.ADULT_SCALE - BipedGait.BABY_SCALE), 0.0, 1.0
	)


## A footfall's share of a full adult step (BipedGait's law: sqrt of scale).
static func stage_weight(s: float) -> float:
	return clampf(sqrt(s / BipedGait.ADULT_SCALE), 0.4, 1.0)


## cfg[key] for a [baby, adult] pair at body scale s, or the number itself.
func at(key: String, s: float) -> float:
	var v: Variant = cfg[key]
	if v is Array:
		var pair: Array = v
		return lerpf(Num.f(pair[0]), Num.f(pair[1]), grown(s))
	return Num.f(v)


## Cross-fade seconds into a state: a start eases in (longer for an adult), a stop is short.
func blend_seconds(next: String, from: String, s: float, fallback: float) -> float:
	if off:
		return fallback
	if next == "walk" and from == "idle":
		return at("start_blend", s)
	if next == "idle" and from == "walk":
		return at("stop_blend", s)
	return fallback


## Eases the stride's stretch toward what keeps the cadence at or under "playback_max".
func ease_warp(speed: float, base_stride: float, dt: float) -> void:
	var want := 1.0
	if not off and base_stride > 0.0:
		var playback := speed / base_stride * _authored
		want = clampf(playback / at("playback_max", 1.0), 1.0, _warp_max)
	warp = lerpf(warp, want, minf(1.0, dt * at("warp_ease", 1.0)))


## The pose made heavier before it is applied: the pelvis sinks by the footfall drop, and the
## toes' fore-aft path stretches by the warp (share: how much of the pose is the walk's; s: the
## body scale, kept for upper()).
func shape(pose: KaijuClips.Pose, rig_scale: float, share: float, s: float) -> void:
	_walk = share
	_s = s
	if off:
		return
	pose.offset.y -= drop / maxf(rig_scale, 0.0001)
	var w := 1.0 + (warp - 1.0) * share
	for i: int in 2:
		pose.feet[i].z = _feet_z + (pose.feet[i].z - _feet_z) * w


## A planted foot lands (hip: hip height, rig units): the pelvis drops and the head and jaw take
## a kick by its strength.
func land(strength: float, hip: float, s: float) -> void:
	if off:
		return
	# An impulse of v reaches about v / omega / KICK_PEAK at its deepest (a damped spring).
	_drop_v += at("drop", s) * hip * strength * _omega("drop_spring", s) * KICK_PEAK
	_nod_v += at("head_kick", s) * at("head_bob", s) * strength * _omega("head_spring", s)
	_jaw_v += at("jaw_kick", s) * strength * _omega("drop_spring", s) * KICK_PEAK


## Steps the springs and lays the upper body over the applied pose: the chest counters the
## pelvis's sway, the head steadies against it and bobs; the jaw drops on the footfall kick.
func upper(rig: KaijuRig, pose: KaijuClips.Pose, dt: float) -> void:
	if off:
		return
	var s := _s
	var walk := _walk
	var w0 := _omega("drop_spring", s)
	var d := KaijuGait.spring(drop, _drop_v, 0.0, w0, _zeta("drop_spring"), dt)
	drop = d.x
	_drop_v = d.y
	var j := KaijuGait.spring(_jaw, _jaw_v, 0.0, w0, _zeta("drop_spring"), dt)
	_jaw = maxf(0.0, j.x)
	_jaw_v = j.y
	var body := rig.global_transform.basis.orthonormalized()
	var fwd := -body.z
	var right := body.x
	var sway := _sway(rig, pose.turns[_pelvis])
	twist = -at("shoulder_twist", s) * sway.dot(Vector3.UP) * walk
	roll = -at("shoulder_roll", s) * sway.dot(fwd) * walk
	var bob := clampf((pose.offset.y - _bob.x) / _bob.y, -1.0, 1.0) * walk
	var n := KaijuGait.spring(
		nod, _nod_v, -bob * at("head_bob", s), _omega("head_spring", s), _zeta("head_spring"), dt
	)
	nod = n.x
	_nod_v = n.y
	if rig.has_bone("spine2"):
		var b := rig.bone("spine2").global_transform.basis.orthonormalized()
		rig.set_world_basis("spine2", Basis(fwd, roll) * Basis(Vector3.UP, twist) * b)
	var steady := -at("head_counter", s)
	for bone_name: String in ["head0", "head1"]:
		if rig.has_bone(bone_name):
			var half := 0.5
			var b := rig.bone(bone_name).global_transform.basis.orthonormalized()
			var turn := (
				Basis(right, -nod * half)
				* Basis(fwd, roll * steady * half)
				* Basis(Vector3.UP, twist * steady * half)
			)
			rig.set_world_basis(bone_name, turn * b)
	if rig.has_bone("jaw") and _jaw > 0.0:
		var b := rig.bone("jaw").global_transform.basis.orthonormalized()
		rig.set_world_basis("jaw", Basis(right, -_jaw) * b)


## The pelvis's turn away from its mean over the walk, as a world rotation vector (rad).
func _sway(rig: KaijuRig, turn: Quaternion) -> Vector3:
	var dev := turn * _mean.inverse()
	if dev.w < 0.0:
		dev = -dev
	var angle := dev.get_angle()
	if angle < 0.000001:
		return Vector3.ZERO
	var frame := rig.bone("spine0").global_transform.basis.orthonormalized() * Basis(turn).inverse()
	return frame * (dev.get_axis() * angle)


func _omega(key: String, s: float) -> float:
	var pair: Array = cfg[key]
	return Num.f(pair[0]) / sqrt(maxf(s, 0.01))


func _zeta(key: String) -> float:
	var pair: Array = cfg[key]
	return Num.f(pair[1])
