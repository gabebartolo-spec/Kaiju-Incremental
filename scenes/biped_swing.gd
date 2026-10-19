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
## Tail whip (species power): length (s) and bend per bone at its height (rad).
const WHIP_SECONDS := 0.35
const WHIP := 0.22
## Arms (posed, never simulated: director, "limp scarves", "outstretched like a zombie"), as the
## Jurassic Park tyrannosaur and Godzilla 2014 carry theirs. Each bone is aimed along a direction
## in the body's heading frame (x outward, y up, -z forward), so it bends at the joint and never
## rolls: the upper arm hangs down and a little forward, the elbow is bent about 60 degrees so
## the forearm reaches forward with the hands resting in front of the belly, below the chest
## (director: a relaxed tyrannosaur hang), the hand drooping loosely. A roar lifts
## and spreads them into a claw; nothing else raises them.
const ARM_UPPER := Vector3(0.15, -0.92, -0.35)
const ARM_FORE := Vector3(-0.25, -0.2, -0.95)
const ARM_HAND := Vector3(-0.2, -0.55, -0.8)
const ARM_UPPER_ROAR := Vector3(0.45, -0.4, -0.8)
const ARM_FORE_ROAR := Vector3(0.2, 0.55, -0.8)
## A small counter-swing with the stride (rad of forward/back swing at the hips' full yaw), and a
## brace in on a turn (per rad/s of yaw rate, at most ARM_BRACE_MAX); both follow a stiff spring
## (rad/s, damping), so the lag is a few degrees and the arms never fling past the body line.
const ARM_STRIDE := 0.14
const ARM_BRACE := 0.25
const ARM_BRACE_MAX := 0.2
const ARM_OMEGA := 18.0
const ARM_ZETA := 0.9
## Claw rake (Claws, D-095): one arm lifts up and out, rakes forward and down across the chest,
## then hangs again; the shares of RAKE_SECONDS at which the lift and the strike end.
const RAKE_SECONDS := 0.45
const RAKE_LIFT := 0.25
const RAKE_STRIKE := 0.5
const ARM_UPPER_RAKE := Vector3(0.5, 0.25, -0.8)
const ARM_FORE_RAKE := Vector3(0.3, 0.75, -0.6)
const ARM_UPPER_ACROSS := Vector3(-0.35, -0.45, -0.85)
const ARM_FORE_ACROSS := Vector3(-0.55, -0.35, -0.75)
const ARM_HAND_ACROSS := Vector3(-0.45, -0.55, -0.7)

var rig: KaijuRig
## The pelvis's drop speed (hip heights/s) and how young the body is (0..1), set each frame.
var hip_drop := 0.0
var youth := 0.0
## The body's turn rate (rad/s), set each frame: the arms brace in against it.
var yaw_rate := 0.0
var _straight: Array[float] = []
var _sweep: Array[float] = []  # the hips' yaw as it travels down the tail, one per bone
var _whip := 0.0  # 1 -> 0 over a tail whip
var _whip_side := 1.0
var _arm_swing := Vector2.ZERO
var _arm_brace := Vector2.ZERO
var _rake := 0.0  # 1 -> 0 over a claw rake
var _rake_side := 1.0


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
## A fast tail whip to one side (-1 left, +1 right): the species power's tail sweep.
func whip(side: float) -> void:
	_whip = 1.0
	_whip_side = side


## A species power's strike to one side (-1 left, +1 right): limb "claw" rakes that arm (Claws),
## anything else whips the tail.
func strike(limb: String, side: float) -> void:
	if limb == "claw":
		_rake = 1.0
		_rake_side = side
	else:
		whip(side)


## Runs the whip down by dt (a gait that poses the tail itself calls this, then whip_yaw()).
func tick_whip(dt: float) -> void:
	_whip = maxf(0.0, _whip - dt / WHIP_SECONDS)


## The whip wave's yaw on tail bone i now (radians; 0 when no whip is running), base first.
func whip_yaw(i: int) -> float:
	if _whip <= 0.0:
		return 0.0
	var wave := clampf((1.0 - _whip) * PI * 1.6 - i * 0.22, 0.0, PI)
	return _whip_side * WHIP * sin(wave)


func update(time: float, hip_yaw: float, roar_open: float, dt: float) -> void:
	tick_whip(dt)
	_rake = maxf(0.0, _rake - dt / RAKE_SECONDS)
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
			bend += whip_yaw(i)  # a whip wave running down the tail, base first
			var yaw := bend + _straight[i]
			var lift := (TAIL_LIFT + TAIL_YOUTH_LIFT * youth) * (1.0 - k * 0.5)
			lift += TAIL_FLICK * hip_drop * k
			tail.drive[i] = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lift)
	_pose_arms(roar_open, hip_yaw, dt)


## The standing arm pose as the rig's rest pose: bone name -> rest basis that turns arm_<side>0/1/2
## (in rig space, which at rest is the heading frame) to point along ARM_UPPER/FORE/HAND. Bends at
## the joints, no roll.
static func rest_arm_bases(rig: KaijuRig) -> Dictionary:
	var out: Dictionary = {}
	var dirs: Array[Vector3] = [ARM_UPPER, ARM_FORE, ARM_HAND]
	for side: String in ["l", "r"]:
		if not rig.has_bone("arm_%s0" % side):
			continue
		var outward := signf(rig.dir_of("arm_%s0" % side).x)
		var above := Basis.IDENTITY  # the parent's rest orientation (the spine has none)
		for i: int in dirs.size():
			var n := "arm_%s%d" % [side, i]
			if not rig.has_bone(n):
				break
			var want := (dirs[i] * Vector3(outward, 1, 1)).normalized()
			var world := Basis(Quaternion(rig.dir_of(n).normalized(), want))
			out[n] = above.inverse() * world
			above = world
	return out


func _pose_arms(roar_open: float, hip_yaw: float, dt: float) -> void:
	var brace := minf(ARM_BRACE_MAX, absf(yaw_rate) * ARM_BRACE)
	var stride := clampf(hip_yaw / BipedBody.HIP_YAW, -1.0, 1.0) * ARM_STRIDE
	_arm_swing = KaijuGait.spring(_arm_swing.x, _arm_swing.y, stride, ARM_OMEGA, ARM_ZETA, dt)
	_arm_brace = KaijuGait.spring(_arm_brace.x, _arm_brace.y, brace, ARM_OMEGA, ARM_ZETA, dt)
	var body := rig.global_transform.basis.orthonormalized()
	var roar := clampf(roar_open, 0.0, 1.0)
	for side: String in ["l", "r"]:
		var names: Array[String] = []
		for i: int in 3:
			if rig.has_bone("arm_%s%d" % [side, i]):
				names.append("arm_%s%d" % [side, i])
		if names.is_empty():
			continue
		var shoulder := rig.bone(names[0]).global_position
		var out := signf((body.inverse() * (rig.tail_world(names[0]) - shoulder)).x)
		# The arm on the side of the trailing leg swings forward (left arm with the right leg).
		var swing := Basis(Vector3.RIGHT, -out * _arm_swing.x * (1.0 - roar))
		var dirs: Array[Vector3] = [
			swing * ARM_UPPER.lerp(ARM_UPPER_ROAR, roar) - Vector3(_arm_brace.x, 0, 0),
			swing * ARM_FORE.lerp(ARM_FORE_ROAR, roar),
			swing * ARM_HAND,
		]
		if _rake > 0.0 and out == _rake_side:
			dirs = _rake_dirs(1.0 - _rake)
		for i: int in names.size():
			var n := names[i]
			var from := rig.bone(n).global_position
			var length := (rig.tail_world(n) - from).length()
			var d := (dirs[i] * Vector3(out, 1, 1)).normalized()
			rig.aim(n, from, from + body * d * length)


## The raking arm's upper, fore and hand directions at t (0..1) through the rake.
func _rake_dirs(t: float) -> Array[Vector3]:
	var rest: Array[Vector3] = [ARM_UPPER, ARM_FORE, ARM_HAND]
	var up: Array[Vector3] = [ARM_UPPER_RAKE, ARM_FORE_RAKE, ARM_FORE_RAKE]
	var across: Array[Vector3] = [ARM_UPPER_ACROSS, ARM_FORE_ACROSS, ARM_HAND_ACROSS]
	var from := rest
	var to := up
	var k := t / RAKE_LIFT
	if t >= RAKE_STRIKE:
		from = across
		to = rest
		k = (t - RAKE_STRIKE) / (1.0 - RAKE_STRIKE)
	elif t >= RAKE_LIFT:
		from = up
		to = across
		k = (t - RAKE_LIFT) / (RAKE_STRIKE - RAKE_LIFT)
	k = smoothstep(0.0, 1.0, k)
	var out: Array[Vector3] = []
	for i: int in rest.size():
		out.append(from[i].lerp(to[i], k))
	return out
