class_name BipedSwing
extends RefCounted
## The reptilian's tail and arms: the tail (a spring chain) is carried low and level as a
## counterweight and sweeps against the hips, the sweep travelling down it so the tip trails; the
## arms are posed muscle, held tucked and forward, braced in on a turn, clawing at a roar.

## Tail: lift per bone (positive lowers), sideways curl straightened (0..1), stiffness and
## gravity share (soft: it lags and droops between steps), the sweep against the hips (per bone,
## times the hip yaw), how fast that sweep travels down the tail (1/s), idle sway.
const TAIL_LIFT := -0.08
## A young tail is carried higher, clear of the legs; the tail flicks against the pelvis drop.
const TAIL_YOUTH_LIFT := -0.02
const TAIL_FLICK := 0.05
const TAIL_STRAIGHTEN := 0.75
const TAIL_STIFFNESS := 7.0
const TAIL_GRAVITY := 0.8
const TAIL_SWEEP := 0.9
const TAIL_DELAY := 4.0
const TAIL_SWAY := 0.03
## At most this much bend per tail bone (rad), so the voxel segments never part.
const TAIL_BEND_MAX := 0.12
## Arms (posed, never simulated: director, "limp scarves"). Each bone is aimed along a direction
## in the chest's space (x outward, y up, -z forward), so it bends at the joint and never rolls:
## upper arm down and forward off the shoulder, forearm raised forward, hand level. A roar lifts
## and spreads them into a claw. A small swing against the hips (times the hip yaw) and a brace
## in on a turn (per rad/s of yaw rate, at most ARM_BRACE_MAX) follow a stiff spring (rad/s,
## damping), so the lag is a few degrees and the arms never fling past the body line.
const ARM_UPPER := Vector3(0.4, -0.75, -0.55)
const ARM_FORE := Vector3(-0.1, 0.3, -0.95)
const ARM_HAND := Vector3(0.0, -0.2, -0.98)
const ARM_UPPER_ROAR := Vector3(0.65, -0.25, -0.7)
const ARM_FORE_ROAR := Vector3(0.25, 0.6, -0.75)
const ARM_SWING := 0.5
const ARM_BRACE := 0.25
const ARM_BRACE_MAX := 0.2
const ARM_OMEGA := 18.0
const ARM_ZETA := 0.9
## A young body's arms stay nearer their sculpted pose (tucking them bares unmodelled chest).
const ARM_YOUTH_EASE := 0.75

var rig: KaijuRig
## The pelvis's drop speed (hip heights/s) and how young the body is (0..1), set each frame.
var hip_drop := 0.0
var youth := 0.0
## The body's turn rate (rad/s), set each frame: the arms brace in against it.
var yaw_rate := 0.0
var _straight: Array[float] = []
var _sweep: Array[float] = []  # the hips' yaw as it travels down the tail, one per bone
var _arm_swing := Vector2.ZERO
var _arm_brace := Vector2.ZERO


func _init(p_rig: KaijuRig) -> void:
	rig = p_rig
	var tail := rig.chain_named("tail0")
	if tail == null:
		return
	tail.stiffness = TAIL_STIFFNESS
	tail.gravity_scale = TAIL_GRAVITY
	var before := 0.0
	for n: String in tail.names:
		var d := rig.dir_of(n)
		var a := atan2(d.x, d.z) if absf(d.z) > 0.0001 else 0.0
		_straight.append(-(a - before) * TAIL_STRAIGHTEN)
		_sweep.append(0.0)
		before = a


## hip_yaw: the pelvis's swing this frame; roar_open 0..1.
func update(time: float, hip_yaw: float, roar_open: float, dt: float) -> void:
	var tail := rig.chain_named("tail0")
	if tail != null:
		var n := tail.drive.size()
		var before := hip_yaw
		for i: int in n:
			# The hips' swing reaches each bone a moment after the one before: the tail whips.
			_sweep[i] = lerpf(_sweep[i], before, minf(1.0, dt * TAIL_DELAY))
			before = _sweep[i]
			var k := float(i + 1) / n
			var sway := sin(time * 0.9 - i * 0.45) * TAIL_SWAY
			var bend := clampf(-TAIL_SWEEP * _sweep[i] + sway, -TAIL_BEND_MAX, TAIL_BEND_MAX)
			var yaw := bend + _straight[i]
			var lift := (TAIL_LIFT + TAIL_YOUTH_LIFT * youth) * (1.0 - k * 0.5)
			lift += TAIL_FLICK * hip_drop * k
			tail.drive[i] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
	_pose_arms(roar_open, hip_yaw, dt)


func _pose_arms(roar_open: float, hip_yaw: float, dt: float) -> void:
	var brace := minf(ARM_BRACE_MAX, absf(yaw_rate) * ARM_BRACE)
	_arm_swing = KaijuGait.spring(_arm_swing.x, _arm_swing.y, hip_yaw, ARM_OMEGA, ARM_ZETA, dt)
	_arm_brace = KaijuGait.spring(_arm_brace.x, _arm_brace.y, brace, ARM_OMEGA, ARM_ZETA, dt)
	if not rig.has_bone("spine2"):
		return
	var chest := rig.bone("spine2").global_transform.basis.orthonormalized()
	var swing := Basis(Vector3.UP, -_arm_swing.x * ARM_SWING)
	var roar := clampf(roar_open, 0.0, 1.0)
	var ease := ARM_YOUTH_EASE * youth
	for side: String in ["l", "r"]:
		var names: Array[String] = []
		for i: int in 3:
			if rig.has_bone("arm_%s%d" % [side, i]):
				names.append("arm_%s%d" % [side, i])
		if names.is_empty():
			continue
		var shoulder := rig.bone(names[0]).global_position
		var out := signf((chest.inverse() * (rig.tail_world(names[0]) - shoulder)).x)
		var dirs: Array[Vector3] = [
			ARM_UPPER.lerp(ARM_UPPER_ROAR, roar) - Vector3(_arm_brace.x, 0, 0),
			ARM_FORE.lerp(ARM_FORE_ROAR, roar),
			ARM_HAND,
		]
		var rest := Basis.IDENTITY
		for i: int in names.size():
			var n := names[i]
			var from := rig.bone(n).global_position
			var length := (rig.tail_world(n) - from).length()
			rest = rest * rig.rest_of(n).basis
			var d := dirs[i] * Vector3(out, 1, 1)
			d = d.normalized().lerp((rest * rig.dir_of(n)).normalized(), ease)
			rig.aim(n, from, from + chest * (swing * d).normalized() * length)
